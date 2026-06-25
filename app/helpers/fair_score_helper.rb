module FairScoreHelper

  def user_apikey
    session[:user].nil? ? '' : session[:user].apikey
  end

  def fairness_service_enabled?
    $FAIRNESS_DISABLED == 'false' || !$FAIRNESS_DISABLED
  end

  def get_fairness_service_url(apikey = user_apikey)
    "#{$FAIRNESS_URL}?portal=#{$HOSTNAME.split('.')[0]}#{apikey.nil? || apikey.empty? ? '' : "&apikey=#{apikey}"}"
  end

  def get_fairness_json(ontologies_acronyms, apikey = user_apikey)
    if Rails.cache.exist?("fairness-#{ontologies_acronyms.gsub(',', '-')}-#{apikey}")
      out = read_large_data("fairness-#{ontologies_acronyms.gsub(',', '-')}-#{apikey}")
    else
      out = '{}'
      begin
        time = Benchmark.realtime do
          conn = Faraday.new do |conn|
            conn.options.timeout = 30
          end
          response = conn.get(get_fairness_service_url(apikey) + "&ontologies=#{ontologies_acronyms}&combined")
          if response.status.eql?(200)
            out = response.body.force_encoding('ISO-8859-1').encode('UTF-8')
            unless out.empty? || out.strip.eql?('{}')
              cache_large_data("fairness-#{ontologies_acronyms.gsub(',', '-')}-#{apikey}", out)
            end
          end
        end
        puts "Call fairness service for: #{ontologies_acronyms} (#{time}s)"
      rescue StandardError
        Rails.logger.warn t('fair_score.fairness_unreachable_warning')
      end
    end
    MultiJson.load(out) rescue {}
  end

  def get_fair_score(ontologies_acronyms, apikey = user_apikey)
    get_fairness_json(ontologies_acronyms, apikey)['ontologies']
  end

  def get_fair_combined_score(ontologies_acronyms, apikey = user_apikey)
    get_fairness_json(ontologies_acronyms, apikey)['combinedScores']
  end

  def get_foops_score(ontology)
    ontology_uri = "#{$UI_URL}/ontologies/#{ontology.acronym}"
    cache_key = "foops-#{ontology.acronym}"
    fail_cache_key = "#{cache_key}-fail"

    return {} if Rails.cache.exist?(fail_cache_key)

    if Rails.cache.exist?(cache_key)
      out = read_large_data(cache_key)
    else
      out = '{}'
      begin
        time = Benchmark.realtime do
          conn = Faraday.new do |f|
            f.options.timeout = 30
            f.options.open_timeout = 10
            f.headers['Content-Type'] = 'application/json;charset=utf-8'
          end
          response = conn.post($FOOPS_URL, { ontologyUri: ontology_uri }.to_json)
          if response.status.eql?(200)
            out = response.body.force_encoding('UTF-8')
            unless out.empty? || out.strip.eql?('{}')
              cache_large_data(cache_key, out, expires_in: 24.hours)
              Rails.cache.delete(fail_cache_key)
            end
          end
        end
        Rails.logger.info "Call FOOPS service for: #{ontology.acronym} (#{time}s)"
      rescue StandardError => e
        Rails.logger.warn "FOOPS unreachable: #{e.message}"
        Rails.cache.write(fail_cache_key, true, expires_in: 10.minutes)
        return {}
      end
    end
    MultiJson.load(out)
  rescue StandardError => e
    Rails.logger.warn "FOOPS JSON parse error: #{e.message}"
    {}
  end

  def create_foops_raw_scores_data(foops_json)
    return nil if foops_json.nil? || foops_json['checks'].nil? || foops_json['checks'].empty?

    checks = foops_json['checks']
    overall = (foops_json['overall_score'].to_f * 100).round(2)

    # Group checks by principle_id (F1, A1, R1, etc.) → O'FAIRe criteria
    criteria_data = Hash.new { |h, k| h[k] = { checks: [] } }
    checks.each { |c| criteria_data[c['principle_id']][:checks] << c }

    # Prepare output in fair_scores_data format
    out = {
      score: overall,
      normalizedScore: overall,
      minScore: 0,
      maxScore: 100,
      medianScore: overall,
      maxCredits: 0,
      principles: {
        labels: [], scores: [], normalizedScores: [],
        maxCredits: [], portalMaxCredits: []
      },
      criteria: {
        labels: [], scores: [], normalizedScores: [],
        portalMaxCredits: [], questions: [],
        maxCredits: [], descriptions: []
      }
    }

    # FOOPS! formula: each check contributes ratio = passed/run, equally weighted
    # Per-principle/criterion = average of check ratios
    principle_order = { 'F' => 1, 'A' => 2, 'I' => 3, 'R' => 4 }
    principle_map = { 'F' => 'Findable', 'A' => 'Accessible', 'I' => 'Interoperable', 'R' => 'Reusable' }
    principles = Hash.new { |h, k| h[k] = { sum_ratios: 0.0, n: 0 } }

    # FAIR principle descriptions
    foops_descriptions = {
      'F1' => 'Ontologies and ontology metadata are assigned a globally unique and persistent identifier.',
      'F2' => 'Ontologies are described with rich ontology metadata.',
      'F3' => 'Ontology metadata clearly and explicitly include the identifier of the ontology they describe.',
      'F4' => 'Ontologies and ontology metadata are registered or indexed in a searchable resource typically an ontology repository.',
      'A1' => 'Ontologies and ontology metadata are retrievable by their identifier using a standardized communication protocol.',
      'A1.1' => 'The protocol to retrieve ontologies and ontology metadata is open, free and universally implementable.',
      'A1.2' => 'The protocol to retrieve ontologies and ontology metadata support authentification and authorization when an ontology has access restriction.',
      'A2' => 'Ontology metadata should be accessible even when the ontology is no longer available.',
      'I1' => 'Ontologies and ontology metadata use a formal, accessible, shared and broadly applicable language for knowledge representation.',
      'I2' => 'Ontologies and ontology metadata use vocabularies that follow FAIR principles.',
      'I3' => 'Ontologies or ontology metadata include qualified references to other (meta)data.',
      'R1' => 'Ontologies and ontology metadata are richly described with a plurality of accurate and relevant attributes.',
      'R1.1' => 'Ontologies and ontology metadata are released with a clear and accessible usage license.',
      'R1.2' => 'Ontologies and ontology metadata are associated with detailed provenance.',
      'R1.3' => 'Ontologies and ontology metadata meet domain-relevant community standards.'
    }

    # Sort criteria: F first, then A, then I, then R; numerically within each principle
    criteria_data.sort_by { |pid, _| [principle_order[pid[0]] || 99, pid] }.each do |pid, data|
      # Per-check ratio = passed / run (safe division)
      ratios = data[:checks].map { |c| c['total_passed_tests'].to_f / [c['total_tests_run'].to_f, 1].max }
      sum_ratios = ratios.sum
      n_checks = ratios.size
      avg_ratio = n_checks > 0 ? sum_ratios / n_checks : 0.0

      out[:criteria][:labels] << pid
      out[:criteria][:descriptions] << (foops_descriptions[pid] || data[:checks].map { |c| c['title'] }.join('; '))
      out[:criteria][:scores] << sum_ratios.round(4)
      out[:criteria][:normalizedScores] << (avg_ratio * 100).round(2)
      out[:criteria][:maxCredits] << n_checks
      out[:criteria][:portalMaxCredits] << n_checks

      # Questions hash — each FOOPS! check becomes one question
      questions = {}
      data[:checks].each do |check|
        questions[check['abbreviation']] = {
          'question'    => check['title'],
          'explanation' => check['explanation'],
          'score'       => check['total_passed_tests'].to_f,
          'maxCredits'  => check['total_tests_run'].to_f,
          'points'      => nil,
          'properties'  => nil
        }
      end
      out[:criteria][:questions] << questions

      principles[pid[0]][:sum_ratios] += sum_ratios
      principles[pid[0]][:n] += n_checks
    end

    %w[F A I R].each do |pk|
      out[:principles][:labels] << principle_map[pk]
      p_data = principles[pk]
      out[:principles][:scores] << p_data[:sum_ratios].round(4)
      out[:principles][:normalizedScores] << (p_data[:n] > 0 ? (p_data[:sum_ratios] / p_data[:n] * 100).round(2) : 0.0)
      out[:principles][:maxCredits] << p_data[:n]
      out[:principles][:portalMaxCredits] << p_data[:n]
    end

    out
  end

  def create_fair_scores_data(fair_scores, count = nil)
    return nil if fair_scores.nil?

    fair_scores_data = {}
    fair_scores_data[:principles] = {labels:[] , scores:[] , normalizedScores: [] , maxCredits: [] , portalMaxCredits: []}
    fair_scores_data[:criteria] = { labels:[] , scores:[] , normalizedScores: [] , portalMaxCredits: [], questions: [] ,maxCredits: [] , descriptions: []}
    fair_scores_data[:score] = fair_scores['score'].to_f.round(2)
    fair_scores_data[:normalizedScore] = fair_scores['normalizedScore'].to_f.round(2)
    fair_scores_data[:minScore] = fair_scores['minScore'].to_f.round(2)
    fair_scores_data[:maxScore] = fair_scores['maxScore'].to_f.round(2)
    fair_scores_data[:medianScore] = fair_scores['medianScore'].to_f.round(2)
    fair_scores_data[:maxCredits] = fair_scores['maxCredits'].to_i
    fair_scores_data[:resourceCount] = count unless  count.nil?

    fair_scores.to_h.select { |k,v| (v.is_a? Hash) }.each do |key, principle|

      fair_scores_data[:principles][:labels] << key
      fair_scores_data[:principles][:scores] << (principle['score'].to_f.round(2))
      fair_scores_data[:principles][:normalizedScores] << (principle['normalizedScore'].to_f.round(2))
      fair_scores_data[:principles][:maxCredits] << principle['maxCredits']
      fair_scores_data[:principles][:portalMaxCredits] << principle['portalMaxCredits']

      principle.to_h.select { |k,v| (v.is_a? Hash)  }.each do  |key , criterion|
        fair_scores_data[:criteria][:labels] << key
        fair_scores_data[:criteria][:descriptions] << criterion['label']
        fair_scores_data[:criteria][:scores] << (criterion['score'].to_f.round(2))
        fair_scores_data[:criteria][:normalizedScores] << (criterion['normalizedScore'].to_f.round(2))

        fair_scores_data[:criteria][:questions] << criterion['results']

        fair_scores_data[:criteria][:maxCredits] << criterion['maxCredits']
        fair_scores_data[:criteria][:portalMaxCredits] << criterion['portalMaxCredits']
      end
    end
    fair_scores_data
  end

  def get_not_obtained_score(fair_scores_data, index)
    fair_scores_data[:criteria][:portalMaxCredits][index] - fair_scores_data[:criteria][:scores][index]
  end

  def get_not_obtained_score_normalized(fair_scores_data, index)
    score_rest = get_rest_score(fair_scores_data,index)
    not_obtained_score = get_not_obtained_score(fair_scores_data , index)

    if  not_obtained_score.positive? && score_rest.positive?
      ((not_obtained_score / fair_scores_data[:criteria][:maxCredits][index]) * 100).round()
    elsif score_rest.zero?
        100 - fair_scores_data[:criteria][:normalizedScores][index]
    else
      0
    end

  end

  def get_rest_score(fair_scores_data, index)
    fair_scores_data[:criteria][:maxCredits][index] - fair_scores_data[:criteria][:portalMaxCredits][index]
  end

  def get_rest_score_normalized(fair_scores_data, index)
    score_rest = get_rest_score(fair_scores_data ,index)
    not_obtained_score_normalized = get_not_obtained_score_normalized(fair_scores_data , index)

    if score_rest.positive?
      100 - not_obtained_score_normalized - fair_scores_data[:criteria][:normalizedScores][index]
    else
      0
    end

  end

  def not_implemented?(question)
    properties = question['properties']
    score = question ['score']
    (properties.nil? || properties.empty?) && score.zero?
  end

  def default_score?(question)
    properties = question['properties']
    score = question ['score']

    (properties.nil? || properties.empty?) && score.positive?
  end

  def get_name_with_out_dot(name)
    name.to_s.gsub(/\./,'')
  end

  def print_score(score)
    number_with_precision(score, precision: 2, strip_insignificant_zeros: true)
  end

  def fairness_link(style: '', ontology: nil)
    custom_style = "font-size: 50px; line-height: 0.5; margin-left: 6px; #{style}".strip
    ontology = ontology || 'all'
    link, target = api_button_link_and_target("#{get_fairness_service_url}&ontologies=#{ontology}&combined=true")
    render IconWithTooltipComponent.new(icon: 'json.svg',link: link, target: target, title: t('fair_score.go_to_api'), size:'small', style: custom_style)  
  end

  private
  require 'zlib'

  def cache_large_data(key, data, chunk_size = 1.megabyte, expires_in: 24.hours)
    compressed_data = Zlib::Deflate.deflate(data)
    total_size = compressed_data.bytesize
    Rails.logger.info "Total compressed data size: #{total_size} bytes"

    chunk_count = (total_size.to_f / chunk_size).ceil

    chunk_count.times do |index|
      chunk_key = "#{key}_chunk_#{index}"
      start_byte = index * chunk_size
      end_byte = start_byte + chunk_size - 1
      chunk = compressed_data.byteslice(start_byte..end_byte)

      unless Rails.cache.write(chunk_key, chunk, expires_in: expires_in)
        Rails.logger.error "Failed to write chunk #{index} for key: #{key}"
        return false
      end
    end

    metadata = { chunk_count: chunk_count }
    Rails.cache.write("#{key}_metadata", metadata, expires_in: expires_in)
    Rails.cache.write(key, true, expires_in: expires_in)
  end

  def read_large_data(key)
    metadata = Rails.cache.read("#{key}_metadata")
    return nil unless metadata

    chunk_count = metadata[:chunk_count]
    data = ''

    chunk_count.times do |index|
      chunk_key = "#{key}_chunk_#{index}"
      chunk = Rails.cache.read(chunk_key)
      return nil unless chunk
      data << chunk
    end

    # Decompress data
    Zlib::Inflate.inflate(data)
  end

end

