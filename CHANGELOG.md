# v0.4.0
- (feat) the approval dialog can ask the agent to create a pull request
- (feat) the architecture diagram marks each component that was changed non-trivially with a red "NON-TRIVIAL" badge; hovering the component shows a summary of the code changes

# v0.3.0
- (feat) the design tab shows the table of contents beside the verdict and the architecture diagram at full width; the problem is shown in the implementation tab only
- (feat) the approval dialog can ask the agent to commit, push, merge and clean up a linked worktree, or follow further written instructions
- (feat) security: the viewer rejects requests from other websites, so a malicious page cannot submit forged feedback or read the repository during a review
- (feat) security: review and feedback files are stored in a directory only the current user can access, so other users on a shared machine cannot read, replace or plant them
- (feat) security: `--new` always starts a review in a freshly created directory, so no review can be redirected into another review's files
- (feat) security: `--host 0.0.0.0` prints a warning that the viewer is reachable from other machines and is not protected against DNS rebinding

# v0.2.0
- (other) removed plugin hooks: it makes no network request at session start and downloads the binary on first use instead
- (bug) an untracked nested Git repository, such as an agent's worktree, is no longer listed in "omitted"
- (feat) Codex support
- (bug) the page shown after submitting now counts every comment, not only line comments
- (feat) a table of contents for the change in the design tab beside the architecture diagram
- (feat) the design tab shows the problem beside the verdict

# v0.1.2
- (other) release downloads are archives containing a binary named review-raven, so it runs without renaming

# v0.1.0
- (feat) initial release

