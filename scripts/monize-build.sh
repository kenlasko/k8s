#!/bin/sh
# Builds Monize from a branch and deploys it to the home cluster, using the suspended
# monize-build CronJob (manifests/apps/monize/overlays/home/cronjob-build.yaml).
# Usage: scripts/monize-build.sh [-d] [branch]   (default branch: main)
#   -d  detach: start the job and exit instead of following its logs
# Needs kubectl (pointed at the home cluster) and jq.

set -eu

NAMESPACE=monize
CRONJOB=monize-build
REPO_URL=https://github.com/kenlasko/monize.git
FOLLOW=1

usage() {
	echo "Usage: $0 [-d] [branch]   (default branch: main)" >&2
	exit 1
}

while getopts d opt; do
	case "$opt" in
		d) FOLLOW=0 ;;
		*) usage ;;
	esac
done
shift $((OPTIND - 1))
[ $# -le 1 ] || usage
BRANCH=${1:-main}

for cmd in kubectl jq; do
	command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd is required" >&2; exit 1; }
done

# Fail here rather than inside the cluster if the branch doesn't exist.
if command -v git >/dev/null 2>&1; then
	if ! git ls-remote --exit-code --heads "$REPO_URL" "refs/heads/$BRANCH" >/dev/null; then
		echo "Branch '$BRANCH' not found in $REPO_URL" >&2
		exit 1
	fi
fi

# Job names are DNS labels (63 chars max), and the build Jobs append "-frontend" to this one:
# lowercase the branch, replace anything else with '-', and keep it short.
slug=$(printf '%s' "$BRANCH" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z0-9-]/-/g' | cut -c1-20 | sed -e 's/-*$//')
JOB="$CRONJOB-$slug-$(date +%Y%m%d%H%M%S)"

# "create job --from" can't override env, so set BRANCH on the resolve container in the generated job.
kubectl create job -n "$NAMESPACE" "$JOB" --from="cronjob/$CRONJOB" --dry-run=client -o json \
	| jq --arg branch "$BRANCH" '
		(.spec.template.spec.initContainers[] | select(.name == "resolve") | .env[] | select(.name == "BRANCH") | .value) = $branch' \
	| kubectl create -f -

if [ "$FOLLOW" -eq 0 ]; then
	echo "Follow with: kubectl logs -n $NAMESPACE job/$JOB -c coordinate -f"
	exit 0
fi

job_failed() {
	[ -n "$(kubectl get job -n "$NAMESPACE" "$JOB" -o jsonpath='{.status.failed}')" ]
}

pod=""
while [ -z "$pod" ]; do
	sleep 2
	pod=$(kubectl get pods -n "$NAMESPACE" -l "job-name=$JOB" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
done

# Stream the coordinator's logs: resolving the branch, then the two builds' progress and the
# rollout. Each build's own log is in its Job; the coordinator prints the command for it, and
# the tail of a failed build's log. A container that never starts ends the loop via job_failed.
for container in resolve coordinate; do
	echo "=== $container"
	while :; do
		state=$(kubectl get pod -n "$NAMESPACE" "$pod" -o jsonpath="{.status.initContainerStatuses[?(@.name==\"$container\")].state}{.status.containerStatuses[?(@.name==\"$container\")].state}")
		case "$state" in
			*running*|*terminated*) break ;;
		esac
		if job_failed; then
			echo "Job $JOB failed before $container started." >&2
			exit 1
		fi
		sleep 3
	done
	kubectl logs -n "$NAMESPACE" "$pod" -c "$container" -f
done

# Wait for the job controller to record the result.
while :; do
	if [ -n "$(kubectl get job -n "$NAMESPACE" "$JOB" -o jsonpath='{.status.succeeded}')" ]; then
		echo "Job $JOB succeeded."
		exit 0
	fi
	if job_failed; then
		echo "Job $JOB failed." >&2
		exit 1
	fi
	sleep 2
done
