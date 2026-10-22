# Working on Wallist

## Shipping to TestFlight: PR, then merge

When a change should reach TestFlight, open a pull request straight away and merge it once its checks pass. Don't start the iOS workflow by hand on the branch first: the PR's run checks the same code, so a manual run only doubles the wait.

1. Push the branch and open the PR. Its iOS run builds, tests, archives and captures screenshots in parallel (about 13–15 minutes).
2. When every check passes and the PR merges cleanly, merge it. The push to `main` signs the archive and uploads it to TestFlight (about 5 minutes); the build number is in the archive job's "Uploaded build" notice.

Never push straight to `main`: the PR's checks are what keep a broken build away from testers.

There's no Swift toolchain in cloud sessions, so the PR run is also the first time Swift changes are compiled. Run `./gradlew :shared:jvmTest` locally before pushing.
