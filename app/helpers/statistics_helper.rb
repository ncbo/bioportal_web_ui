module StatisticsHelper

  def ontologies_by_year_month
    data = LinkedData::Client::Analytics.all.to_h
    data.delete(:links)
    data.delete(:context)
    year_month_count = {}
    year_month_visits = {}
    acronyms = []
    data.each do |acronym, ont|
      ont.each do |year, months|
        next if year.eql?(:links) || year.eql?(:context)
        months.each do |month, count|
          next if month.eql?(:links) || month.eql?(:context)
          year_month_count[[year.to_s.to_i, month.to_s.to_i]] ||= []
          year_month_visits[[year.to_s.to_i, month.to_s.to_i]] = count + (year_month_visits[[year.to_s.to_i, month.to_s.to_i]] || 0)

          if !count.zero? && !acronyms.include?(acronym)
            year_month_count[[year.to_s.to_i, month.to_s.to_i]] << acronym
            acronyms << acronym
          end
        end
      end
    end
    year_month_visits = year_month_visits.sort_by { |(year, month), _| [year, month] }.to_h
    [year_month_count, year_month_visits]
  end

  def string_year_month(year, month)
    DateTime.parse("#{year}/#{month}").strftime("%b %Y")
  end
  def group_by_year_month(data, fallback: nil)
    grouped = data.group_by do |x|
      created = x.respond_to?(:created) ? x.created : nil
      if created.nil? || created.to_s.strip.empty?
        fallback
      else
        [Date.parse(created).year, Date.parse(created).month]
      end
    end
    grouped.delete(nil)
    grouped.sort_by { |(year, month), _| [year, month] }.to_h
  end

  STATISTICS_SERIES_COLORS = {
    ontologies: '#1976D2',
    users: '#F57C00',
    projects: '#7B1FA2',
    agents: '#2E7D32'
  }.freeze

  def statistics_chart_datasets(series)
    series.map do |entry|
      key = entry[:key]
      color = STATISTICS_SERIES_COLORS[key]
      dataset = {
        label: entry[:label],
        data: entry[:data],
        borderColor: color,
        backgroundColor: "#{color}1A",
        pointBackgroundColor: color,
        pointBorderColor: '#fff',
        pointHoverBackgroundColor: '#fff',
        pointHoverBorderColor: color,
        pointRadius: 3,
        pointHoverRadius: 5,
        borderWidth: 2,
        cubicInterpolationMode: 'monotone',
        tension: 0.4,
        fill: false
      }
      dataset[:cumulative] = true if entry[:cumulative]
      dataset[:yAxisID] = entry[:axis] if entry[:axis]
      dataset[:borderDash] = entry[:dashed] if entry[:dashed]
      dataset[:hidden] = true if entry[:hidden]
      dataset
    end.to_json
  end

  def statistics_kpi_cards(merged_data)
    [
      { key: :ontologies, label: t('statistics.ontologies'), series: merged_data[:visits][2] },
      { key: :users,      label: t('statistics.users'),      series: merged_data[:visits][0] },
      { key: :projects,   label: t('statistics.projects'),   series: merged_data[:visits][1] },
      { key: :agents,     label: t('statistics.agents'),     series: merged_data[:visits][3] }
    ].map do |kpi|
      series = Array(kpi[:series])
      total = series.last || 0
      previous = series[-2] || 0
      kpi.merge(total: total, delta: total - previous, color: STATISTICS_SERIES_COLORS[kpi[:key]])
    end
  end

  def merge_time_evolution_data(data)
    min_year = data.map { |x| x.keys.first&.first }.compact.min
    old = data.size.times.map { |x|  0 }

    visits_data = { visits: data.size.times.map { |x|  [] }, labels: [] }

    today = Date.today
    (min_year..today.year).each do |year|
      (1..12).each do |month|
        break if year == today.year && month > today.month

        data.each_with_index do |x , i|
          old[i] += x[[year, month]]&.size || 0
        end

        next if old.sum.zero?

        data.each_index do |i|
          visits_data[:visits][i] << old[i]
        end

        visits_data[:labels] << string_year_month(year, month)
      end
    end
    visits_data
  end

end
