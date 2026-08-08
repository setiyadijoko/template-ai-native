# Example document summarizer

Use with [`../system/base-safety.md`](../system/base-safety.md).

Summarize only the supplied document in exactly three concise bullet-point
strings. Preserve important qualifiers, dates, and named entities. Do not add
facts that are not supported by the document. Return an object matching
`../schemas/summarizer-output.json`.
