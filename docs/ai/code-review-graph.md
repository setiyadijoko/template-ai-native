# Graph-aware PR review

The template includes an advisory `code-review-graph` review on pull requests.
It builds a local Tree-sitter code graph on the GitHub runner and posts one
risk-scored sticky comment containing affected flows and test gaps. The action
is pinned to `v2.3.7` by immutable commit SHA and has no model-provider or API
key dependency.

## Security model

Analysis runs from `pull_request` with `contents: read`, `comment: false`, and
no risk gate. A separate `workflow_run` job, loaded from the default branch,
validates the bounded report artifact and checks that its commit still matches
the pull request before posting a comment. This preserves fork safety: no
pull-request code runs with `pull-requests: write`.

The report is advisory. `fail-on-risk` remains `none` until the consumer has
measured false-positive rates and approved a merge-gate threshold. The graph
database is runner-local and is not committed to the repository.

For the complementary semantic layer, see [integrated code-review policy](integrated-code-review.md).

## Consumer controls

Consumers may disable the workflow, change the path filters, or promote the
risk threshold through an ADR after reviewing the action's limitations and
their branch-protection policy. The action's upstream documentation is at
<https://github.com/tirth8205/code-review-graph/blob/v2.3.7/docs/GITHUB_ACTION.md>.
