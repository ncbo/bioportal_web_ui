// Builds the grand-total summary text shown in the annotator results tables'
// top-start `div` layout feature, replacing the old #result_counts div. Column
// index 2 (Type) holds 'direct' / 'ancestor' / 'mapping' / '' for each row. The
// total and breakdown always reflect the full result set ({ search: 'none' }),
// regardless of any ColumnControl column filters; the per-page "Showing X to Y
// of Z" summary is handled separately by the default `info` control in the
// bottom-start slot.
//
// The `div` feature is static, so callers set this string on the table's `draw`
// event (see the annotator table controllers).
export function buildAnnotationsSummary(api) {
  const counts = { direct: 0, ancestor: 0, mapping: 0 };

  api
    .column(2, { search: 'none' })
    .data()
    .each((type) => {
      if (type in counts) {
        counts[type] += 1;
      }
    });

  const total = api.rows({ search: 'none' }).count();

  return (
    `Total results: ${total} ` + `(direct ${counts.direct} / ancestor ${counts.ancestor} / mapping ${counts.mapping})`
  );
}
