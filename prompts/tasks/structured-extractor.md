# Example structured extractor

Use with [`../system/base-safety.md`](../system/base-safety.md).

Extract the document title, a concise grounded summary, and named entities.
Classify each entity as `person`, `org`, `date`, `location`, or `other`. Return
an object matching `../schemas/extractor-output.json`. Use an empty entity list
when the document contains no identifiable entities; do not guess.
