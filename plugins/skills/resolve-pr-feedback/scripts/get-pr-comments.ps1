# PowerShell 5.1 twin of get-pr-comments (bash).
# Identical args + stdout contract:
#   get-pr-comments.ps1 PR_NUMBER [OWNER/REPO]
# Emits one JSON object: { review_threads:[{node}], pr_comments:[], review_bodies:[] }
# Native Windows: uses ConvertFrom/ConvertTo-Json instead of jq (no jq dependency).
# GraphQL $-variables ($owner/$repo/$pr/$endCursor) are preserved verbatim by
# single-quoted here-strings — PowerShell must NOT interpolate them; gh resolves
# them from the -f/-F flags.
param([string]$PRNumber, [string]$OwnerRepo)

$ErrorActionPreference = "Stop"

if (-not $PRNumber) {
    [Console]::Error.WriteLine("Usage: get-pr-comments PR_NUMBER [OWNER/REPO]")
    [Console]::Error.WriteLine("Example: get-pr-comments 123")
    [Console]::Error.WriteLine("Example: get-pr-comments 123 raptoravis/cora")
    exit 1
}

if ($OwnerRepo) {
    $parts = $OwnerRepo -split "/", 2
    $Owner = $parts[0]
    $Repo = $parts[1]
} else {
    $view = gh repo view --json owner,name 2>$null
    if ($view) {
        $info = $view | ConvertFrom-Json
        $Owner = $info.owner.login
        $Repo = $info.name
    }
}

if (-not $Owner -or -not $Repo) {
    [Console]::Error.WriteLine("Error: could not resolve owner/repo. Run get-pr-comments from inside the target git repository, or pass OWNER/REPO as the second argument (e.g., get-pr-comments $PRNumber owner/repo).")
    exit 1
}

# GraphQL queries — single-quoted here-strings so $owner/$repo/$pr/$endCursor
# reach gh literally (they are GraphQL variables, not PowerShell variables).
$threadsQuery = @'
query Threads($owner: String!, $repo: String!, $pr: Int!, $endCursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      author { login }
      reviewThreads(first: 100, after: $endCursor) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          originalLine
          startLine
          originalStartLine
          comments(first: 100) {
            nodes {
              id
              author { login }
              body
              createdAt
              url
            }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
'@

$commentsQuery = @'
query Comments($owner: String!, $repo: String!, $pr: Int!, $endCursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      comments(first: 100, after: $endCursor) {
        nodes {
          id
          author { login }
          body
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
'@

$reviewsQuery = @'
query Reviews($owner: String!, $repo: String!, $pr: Int!, $endCursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviews(first: 100, after: $endCursor) {
        nodes {
          id
          author { login }
          body
          state
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
'@

# gh emits UTF-8 bytes; on legacy ANSI code pages (e.g. zh-CN/GBK) PowerShell
# would decode them per the active code page and ConvertFrom-Json would throw or
# garble CJK/emoji. Force UTF-8 for the native stdout pipeline, restore after.
$prevOutputEncoding = [Console]::OutputEncoding
$prevPrefEncoding = $OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# gh api graphql --paginate --slurp emits one JSON array (every page).
$threadsPages  = gh api graphql --paginate --slurp -f "owner=$Owner" -f "repo=$Repo" -F "pr=$PRNumber" -f "query=$threadsQuery" | ConvertFrom-Json
$commentsPages = gh api graphql --paginate --slurp -f "owner=$Owner" -f "repo=$Repo" -F "pr=$PRNumber" -f "query=$commentsQuery" | ConvertFrom-Json
$reviewsPages  = gh api graphql --paginate --slurp -f "owner=$Owner" -f "repo=$Repo" -F "pr=$PRNumber" -f "query=$reviewsQuery" | ConvertFrom-Json

# Replicates the jq filter in get-pr-comments (bash twin): PR-author exclusion and
# blank-body exclusion are the only structural exclusions. Content, identity, and
# surface are evidence for the resolver, not deterministic exclusions. CI/status
# bots can carry actionable setup or posting failures, and automation identities
# can transport human-authored reviews. Keep this limited to structural
# loop-prevention facts: blank bodies and messages known to come from the PR
# author. If the PR author is unavailable ($null for deleted users), fail open.
$authorLogin = $threadsPages[0].data.repository.pullRequest.author.login

$allThreads  = foreach ($p in $threadsPages)  { foreach ($n in $p.data.repository.pullRequest.reviewThreads.nodes) { , $n } }
$allComments = foreach ($p in $commentsPages) { foreach ($n in $p.data.repository.pullRequest.comments.nodes)      { , $n } }
$allReviews  = foreach ($p in $reviewsPages)  { foreach ($n in $p.data.repository.pullRequest.reviews.nodes)       { , $n } }

$reviewThreads = foreach ($t in $allThreads) { if ($t.isResolved -eq $false) { [pscustomobject]@{ node = $t } } }

function Test-Visible($node, $authorLogin) {
    if ($authorLogin -and $node.author.login -eq $authorLogin) { return $false }
    $body = if ($node.body) { "$($node.body)" } else { "" }
    if ($body -match '^\s*$') { return $false }
    return $true
}

$prComments   = foreach ($c in $allComments) { if (Test-Visible $c $authorLogin) { $c } }
$reviewBodies = foreach ($r in $allReviews)  { if (Test-Visible $r $authorLogin) { $r } }

[pscustomobject]@{
    review_threads = @($reviewThreads)
    pr_comments    = @($prComments)
    review_bodies  = @($reviewBodies)
} | ConvertTo-Json -Depth 20

[Console]::OutputEncoding = $prevOutputEncoding
$OutputEncoding = $prevPrefEncoding
