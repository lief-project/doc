#!/usr/bin/env python3
import sys
import os
import re
import logging
import pathlib
import subprocess
import shutil

LOG_LEVEL = logging.DEBUG

logging.getLogger().addHandler(logging.StreamHandler())
logging.getLogger().setLevel(LOG_LEVEL)
logger = logging.getLogger(__name__)

CURRENTDIR = pathlib.Path(__file__).resolve().parent
REPODIR    = CURRENTDIR.parent

DEPLOY_KEY = os.getenv("LIEF_AUTOMATIC_BUILDS_KEY", None)
DEPLOY_IV  = os.getenv("LIEF_AUTOMATIC_BUILDS_IV", None)

GIT_USER  = "lief-ci-doc"
GIT_EMAIL = f"{GIT_USER}@lief.re"

LIEF_SRC_BRANCH       = os.getenv("LIEF_BRANCH", "master")
LIEF_WEBSITE_REPO     = "https://github.com/lief-project/lief-project.github.io.git"
LIEF_WEBSITE_DIR      = REPODIR / "lief-project.github.io"
LIEF_WEBSITE_SSH_REPO = "git@github.com:lief-project/lief-project.github.io.git"


CI_CWD = os.getenv("CIRCLE_WORKING_DIRECTORY", None)

SSH_DIR = pathlib.Path("~/.ssh").expanduser().resolve()


PYTHON  = shutil.which("python")
GIT     = shutil.which("git")
TAR     = shutil.which("tar")
OPENSSL = shutil.which("openssl")
MV      = shutil.which("mv")
RM      = shutil.which("rm")

if DEPLOY_KEY is None:
    print("Deploy key is not set!", file=sys.stderr)
    sys.exit(1)

if DEPLOY_IV is None:
    print("Deploy IV is not set!", file=sys.stderr)
    sys.exit(1)

def setup_lief_website(branch="master"):
    target_dir = "latest"
    if LIEF_SRC_BRANCH != "master" and len(LIEF_SRC_BRANCH) > 0:
        target_dir = LIEF_SRC_BRANCH.replace("/", "-").replace("_", "-")
    print(f"Target dir: {target_dir}")
    # 1. Clone the repo
    p = subprocess.Popen(f"{GIT} clone --branch=master -j8 --single-branch {LIEF_WEBSITE_REPO}",
            shell=True, cwd=REPODIR)
    p.wait()

    if p.returncode:
        sys.exit(1)

    cmds = [
        "chmod 700 .git",
        f"{GIT} config user.name '{GIT_USER}'",
        f"{GIT} config user.email '{GIT_EMAIL}'",
        f"{GIT} reset --soft HEAD~1",
        f"{GIT} ls-files -v",
    ]

    for cmd in cmds:
        p = subprocess.Popen(cmd, shell=True, cwd=LIEF_WEBSITE_DIR)
        p.wait()

        if p.returncode:
            sys.exit(1)

    cmds = [
        f"mkdir -p {LIEF_WEBSITE_DIR}/doc/{target_dir}",
        # Remove old doc
        f"{RM} -rf  {LIEF_WEBSITE_DIR}/doc/{target_dir}/*",
        # Copy sphinx & doxygen
        f"{MV} --force {CI_CWD}/doc/* {LIEF_WEBSITE_DIR}/doc/{target_dir}/",
        # Commit
        f"{GIT} add .",
        f"{GIT} commit -m 'Update {target_dir} doc'"
    ]

    for cmd in cmds:
        p = subprocess.Popen(cmd, shell=True, cwd=LIEF_WEBSITE_DIR)
        p.wait()

        if p.returncode:
            sys.exit(1)

    setup_ssh()
    for i in range(10):
        p = subprocess.Popen(f"{GIT} push --force {LIEF_WEBSITE_SSH_REPO} master", shell=True, cwd=LIEF_WEBSITE_DIR)
        p.wait()

        if p.returncode == 0:
            break

        cmds = [
            f"{GIT} branch -a -v",
            f"{GIT} fetch -v origin master",
            f"{GIT} branch -a -v",
            f"{GIT} rebase -s recursive -X theirs FETCH_HEAD",
            f"{GIT} branch -a -v",
        ]
        for c in cmds:
            p = subprocess.Popen(c, shell=True, cwd=LIEF_WEBSITE_DIR)
            p.wait()



def fix_ssh_perms():
    if not SSH_DIR.is_dir():
        return

def start_ssh_agent():
    process = subprocess.run('ssh-agent', stdout=subprocess.PIPE, universal_newlines=True)
    OUTPUT_PATTERN = re.compile(r'SSH_AUTH_SOCK=(?P<socket>[^;]+).*SSH_AGENT_PID=(?P<pid>\d+)', re.MULTILINE | re.DOTALL)
    match = OUTPUT_PATTERN.search(process.stdout)
    if match is None:
        raise RuntimeError("Can't start ssh-agent")

    agent_data = match.groupdict()
    logger.info(f'ssh agent data: {agent_data!s}')
    logger.info('Exporting ssh agent environment variables' )

    os.environ['SSH_AUTH_SOCK'] = agent_data['socket']
    os.environ['SSH_AGENT_PID'] = agent_data['pid']

    process = subprocess.run('ssh-add -L', shell=True)

def add_ssh_key(keypath):
    process = subprocess.run(['ssh-add', keypath])
    if process.returncode != 0:
        raise Exception(f'Failed to add the key: {keypath}')

def setup_ssh():
    if not SSH_DIR.is_dir():
        SSH_DIR.mkdir(mode=0o700)

    fix_ssh_perms()
    deploy_key_path = (REPODIR / ".github" / "deploy-key.enc").as_posix()
    output_key_path = (REPODIR / ".git" / "deploy-key")
    cmd = f"{OPENSSL} aes-256-cbc -K {DEPLOY_KEY} -iv {DEPLOY_IV} -in {deploy_key_path} -out {output_key_path.as_posix()} -d"

    kwargs = {
        'shell':  True,
        'cwd':    REPODIR,
        'stdout': subprocess.DEVNULL,
        'stderr': subprocess.DEVNULL,
    }

    p = subprocess.Popen(cmd, **kwargs)
    p.wait()

    if p.returncode:
        sys.exit(1)
    output_key_path.chmod(0o600)
    start_ssh_agent()
    add_ssh_key(output_key_path.as_posix())
    fix_ssh_perms()

    cmd = f"ssh-keyscan -H github.com >> {SSH_DIR.as_posix()}/known_hosts"

    kwargs = {
        'shell':      True,
        'cwd':        REPODIR,
    }

    p = subprocess.Popen(cmd, **kwargs)
    p.wait()

    if p.returncode:
        sys.exit(1)


def main(argv):
    setup_lief_website()
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))

