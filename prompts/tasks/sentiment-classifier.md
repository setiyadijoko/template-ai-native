# Example sentiment classifier

Use with [`../system/base-safety.md`](../system/base-safety.md).

Classify the supplied short comment as exactly one of `positive`, `neutral`, or
`negative`. Return an object matching `../schemas/sentiment-output.json` with a
confidence value from 0 to 1.

Use `neutral` when the text is factual, mixed, or insufficient to determine a
clear sentiment. Do not infer sentiment from information outside the comment.
