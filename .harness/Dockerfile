# syntax=docker/dockerfile:1.7
# Project runner image for ash_backpex. Extends the published Harness base at an
# immutable digest with this repository's checkout, compiled dependencies (the
# library in test, the demo in dev), and the fixed eno-harness-runner-v1 hooks.
#
# Build and publish from the repository root (see .harness/fly.runner.toml):
#
#   fly deploy --config .harness/fly.runner.toml --build-only --push \
#     --image-label "ash-backpex-runner-$(date +%Y%m%d%H%M)" \
#     --build-arg TARGET_SHA="$(git rev-parse HEAD)" \
#     --build-secret github_token="$(gh auth token)"
#
# Record the published digest in .harness/project.json, commit, preview, accept.
ARG HARNESS_RUNNER_IMAGE=registry.fly.io/eno-harness@sha256:3976c433e63203d5fe9441cdc4b154ff334ec972a1bdd5a658023deee8929d7d

FROM ${HARNESS_RUNNER_IMAGE} AS source

ARG TARGET_REPO=https://github.com/enoonan/ash_backpex.git
ARG TARGET_REF=main
ARG TARGET_SHA

WORKDIR /workspace
RUN --mount=type=secret,id=github_token,uid=1000,required=true \
    test -n "$TARGET_SHA" \
    && GITHUB_TOKEN="$(cat /run/secrets/github_token)" \
       git -c 'credential.helper=!f() { echo "username=x-access-token"; echo "password=${GITHUB_TOKEN}"; }; f' \
       clone --branch "$TARGET_REF" "$TARGET_REPO" repo \
    && git -C repo remote set-url origin "$TARGET_REPO" \
    && git -C repo reset -q --hard "$TARGET_SHA" \
    && git -C repo rev-parse --verify "$TARGET_SHA^{commit}"

FROM ${HARNESS_RUNNER_IMAGE} AS deps

WORKDIR /workspace/repo
COPY --from=source --chown=runner:runner /workspace/repo/mix.exs /workspace/repo/mix.lock ./
COPY --from=source --chown=runner:runner /workspace/repo/config ./config
RUN mix deps.get \
  && MIX_ENV=test mix deps.compile \
  && MIX_ENV=dev mix deps.compile

FROM ${HARNESS_RUNNER_IMAGE} AS runner

WORKDIR /workspace/repo
COPY --from=source --chown=runner:runner /workspace/repo ./
COPY --from=deps --chown=runner:runner /workspace/repo/deps ./deps
COPY --from=deps --chown=runner:runner /workspace/repo/_build ./_build
COPY --chown=runner:runner .harness/hooks/ /harness/project/
RUN chmod 755 /harness/project/setup /harness/project/verify-full /harness/project/verify-check \
  && MIX_ENV=test mix compile \
  && cd demo \
  && MIX_ENV=dev mix deps.get \
  && MIX_ENV=dev mix compile

CMD ["/harness/app/bin/eno_harness", "start"]
