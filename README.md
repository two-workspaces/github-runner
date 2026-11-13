# Deploy and Host GitHub Actions Runner on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/github-runner?referralCode=sLjDXb&utm_medium=integration&utm_source=button&utm_campaign=github-runner)

A self-hosted GitHub Actions runner runs your workflow jobs on your own machine instead of GitHub's. This template runs one on Railway for a repository or a whole organization. It registers itself and keeps its registration across redeploys. Jobs get sudo, git, Node (through `actions/setup-node`), Python and a C compiler.

This is a community template, not made or supported by GitHub.

## About Hosting GitHub Actions Runner

A runner registers once with a token that expires after an hour, then has to keep that registration. On a container platform, a redeploy usually wipes it, and the runner can't register again with the expired token. This template keeps the registration on a volume, so redeploys and restarts reconnect as the same runner.

**Set it up:** set `GITHUB_URL` to the repository (`https://github.com/OWNER/REPO`) or organization (`https://github.com/ORG`). Then give it one of these:

- `GITHUB_PAT`, a personal access token that can manage runners. A fine-grained token needs repository **Administration: read and write**, or for an organization, **Self-hosted runners: read and write**. A classic token needs `repo` (or `admin:org` for an organization). With it, the runner registers itself whenever it needs to, for example after you remove it on GitHub.
- `RUNNER_TOKEN`, the registration token GitHub shows under **Settings > Actions > Runners > New self-hosted runner**. It works once, within an hour; the volume keeps the runner registered after that.

**Use it:** in a workflow, set `runs-on: [self-hosted, railway]`. Change the label with `RUNNER_LABELS`.

## Common Use Cases

- Jobs that need more time, memory or CPU than GitHub's free runners, billed by Railway's usage
- Jobs that reach private services in the same Railway project, such as a database for integration tests or migrations
- Deploy jobs for services on Railway's private network

## Dependencies for GitHub Actions Runner Hosting

- A GitHub repository or organization where you can add runners
- A token: a personal access token that can manage runners, or a registration token

### Deployment Dependencies

- [About self-hosted runners](https://docs.github.com/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners)
- [actions/runner](https://github.com/actions/runner)
- [Template source](https://github.com/two-workspaces/github-runner)

### Implementation Details

- **Tested on Railway:** the runner registered from a registration token and ran a workflow with `actions/checkout`, `actions/setup-node`, `npx`, sudo, Python and gcc, including at 0.5 GB of memory; a redeploy without any token reconnected as the same runner; a redeploy shut it down cleanly; after the runner was removed on GitHub it said so in the logs instead of crash-looping. Requesting a registration token with a personal access token was tested against GitHub's API, but not from a Railway deploy.
- **No Docker:** Railway doesn't run a Docker daemon inside services, so `container:` jobs, `services:` containers, Docker-based actions and `docker build` fail. JavaScript and composite actions, which are most actions, work.
- **Your tokens stay out of jobs:** `GITHUB_PAT` and `RUNNER_TOKEN` are removed from the environment before the runner starts, so workflow steps can't read them.
- **Security:** a self-hosted runner runs whatever the workflow says. Use it on private repositories, or on public ones only with workflows that don't run for pull requests from forks.
- **One job at a time:** a runner takes one job at a time. For parallel jobs, deploy the template again, or add replicas in the service's settings: each replica registers as its own runner. Name them apart with `RUNNER_NAME` if you deploy several services to the same repository.
- **Memory:** about 100 MB idle. Jobs use what they need: light jobs ran at 0.5 GB, but builds of large projects want 2 GB or more.
- **Updates:** the runner updates itself when GitHub releases a new version. Diagnostic logs are in `/home/runner/_diag`.
- **Image:** `ghcr.io/two-workspaces/github-runner`, built from this repository's Dockerfile on `ghcr.io/actions/actions-runner:2.338.2`, with build-essential, Python 3, zip and xz added.

## Why Deploy GitHub Actions Runner on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying GitHub Actions Runner on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
