import requests
import logging
import sys
import io
import zipfile
import os
import time
import tarfile
import subprocess
import pathlib
import tempfile
import sysconfig
from contextlib import closing

LOG_LEVEL = logging.INFO

logging.getLogger().addHandler(logging.StreamHandler(stream=sys.stdout))
logging.getLogger().setLevel(LOG_LEVEL)
logger = logging.getLogger(__name__)

PYTHON_VERSION           = sysconfig.get_config_var("VERSION")
LIEF_TOKEN               = os.getenv("LIEF_CIRCLE_TOKEN", None)
LIEF_WORKFLOW_NAME       = "Linux x86-64"
LIEF_SDK_ARTIFACT_NAME   = "linux-x86-64-sdk"
LIEF_WHEEL_ARTIFACT_NAME = f"linux-x86-64-python{PYTHON_VERSION}-wheel"
BASE_URL                 = "https://api.github.com/repos/lief-project/lief"
BRANCH                   = os.getenv("LIEF_BRANCH", "main")
# As defined in <github>:.github/workflows/linux-x86-64.yml

if LIEF_TOKEN is None or len(LIEF_TOKEN) == 0:
    logger.error("LIEF_TOKEN not set!")
    sys.exit(1)

def sizeof_fmt(num, suffix="B"):
    for unit in ["", "Ki", "Mi", "Gi", "Ti", "Pi", "Ei", "Zi"]:
        if abs(num) < 1024.0:
            return f"{num:3.1f}{unit}{suffix}"
        num /= 1024.0
    return f"{num:.1f}Yi{suffix}"

def run_pip_install(file):
    cmd = [
        sys.executable,
        "-m", "pip", "install", "--break-system-packages", "--no-cache-dir",
        "--force-reinstall",
        file
    ]
    logger.info("Excuting: %s", " ".join(cmd))
    subprocess.check_call(cmd)


def list_workflow():
    url = f"{BASE_URL}/actions/runs"
    headers = {
        "Accept": "application/vnd.github.v3+json"
    }
    r = requests.get(url, headers=headers, timeout=3)
    if r.status_code != 200:
        logger.error("Error while trying to list workflow's actions: %s", r.text)
        return None
    return r.json()

def is_success(workflow, branch):
    return workflow["head_branch"] == branch

def workflow_date(workflow):
    return workflow["updated_at"]

def get_workflow(branch: str):
    workflow = list_workflow()
    if workflow is None:
        return []

    flows = [wf for wf in workflow["workflow_runs"] if is_success(wf, branch)]
    flows.sort(key=workflow_date, reverse=True)
    return flows

def get_artifacts(url):
    headers = {
        "Accept": "application/vnd.github.v3+json"
    }
    logger.info("Getting artifact at: %s", url)
    r = requests.get(url, headers=headers, timeout=3)
    if r.status_code != 200:
        logger.error("Error while trying to list workflow's actions: %s", r.text)
        return None
    return r.json()

def not_expired(element) -> bool:
    return not element["expired"]

def process_sdk(name, size, url, output_dir):
    logger.info("Downloading LIEF SDK at '%s'", url)
    headers = {
        "Authorization": f"token {LIEF_TOKEN}"
    }
    r = requests.get(url, stream=True, headers=headers, timeout=3)
    if r.status_code != 200:
        logger.error(r.text)
        sys.exit(1)

    logger.info("Downloading %s (%s) ...", name, sizeof_fmt(size))
    with closing(r), zipfile.ZipFile(io.BytesIO(r.content)) as archive:
        for member in archive.infolist():
            if member.filename.startswith("LIEF-") and member.filename.endswith(".tar.gz"):
                logger.info("Extracting %s in %s ...", member.filename, output_dir)
                with archive.open(member.filename) as tar_sdk:
                    with tarfile.open(mode="r|gz", fileobj=tar_sdk) as sdk:
                        sdk.extractall(output_dir)
                        logger.info("Extracted!")
                        return True
    return False

def process_wheels(name, size, url):
    logger.info("Downloading LIEF Python Wheels at '%s'", url)
    headers = {
        "Authorization": f"token {LIEF_TOKEN}"
    }
    r = requests.get(url, stream=True, headers=headers, timeout=3)
    if r.status_code != 200:
        logger.error(r.text)
        sys.exit(1)

    tag = "cp{major}{minor}-cp{major}{minor}".format(major=sys.version_info.major, minor=sys.version_info.minor)
    logger.info("Downloading %s (%s) ...", name, sizeof_fmt(size))
    with closing(r), zipfile.ZipFile(io.BytesIO(r.content)) as archive:
        for member in archive.infolist():
            if tag in member.filename:
                with tempfile.TemporaryDirectory() as tmp:
                    logger.info("Extracting %s in %s", member.filename, tmp)
                    archive.extract(member, tmp)
                    wheel_path = pathlib.Path(tmp) / member.filename
                    run_pip_install(wheel_path.as_posix())
                    return True
    return False


def process_artifacts(artifacts) -> bool:
    wheel_found = False
    sdk_found = False
    for element in filter(not_expired, artifacts["artifacts"]):
        name = element["name"]
        size = element["size_in_bytes"]
        url  = element["archive_download_url"]
        logger.info("%-30s (%s): %s", name, sizeof_fmt(size), url)
        if name == LIEF_WHEEL_ARTIFACT_NAME:
            wheel_found = True
            if process_wheels(name, size, url):
                logger.info("LIEF Python wheel installed")
            else:
                logger.error("Error while installing the Python wheel")
                return False
        elif name == LIEF_SDK_ARTIFACT_NAME:
            cwd = pathlib.Path(".").resolve().absolute()
            sdk_found = True
            if process_sdk(name, size, url, cwd.as_posix()):
                logger.info("LIEF SDK extracted")
            else:
                logger.error("Error while extracting the SDK")
                return False

    if not wheel_found:
        logger.error("Can't find wheel artifact: %s", LIEF_WHEEL_ARTIFACT_NAME)

    if not sdk_found:
        logger.error("Can't find SDK artifact: %s", LIEF_SDK_ARTIFACT_NAME)

    if not wheel_found or not sdk_found:
        return False
    return True

def bootstrap(try_count: int = 4):
    logger.info("Using branch: %s", BRANCH)
    for wf in get_workflow(BRANCH):
        name    = wf["name"]
        art_url = wf["artifacts_url"]
        logger.info("%-30s: %s", name, art_url)
        if name == LIEF_WORKFLOW_NAME:
            ar = get_artifacts(art_url)
            if not process_artifacts(ar):
                logger.error("Error while trying to process the artifacts")
                if try_count > 0:
                    time.sleep(6)
                    return bootstrap(try_count - 1)
                return 1

            return 0
    if try_count > 0:
        logger.error("Workflow '%s' not found. Try again %d times after 2s", LIEF_WORKFLOW_NAME, try_count)
        time.sleep(2)
        return bootstrap(try_count - 1)
    logger.error("did not find workflow %s", LIEF_WORKFLOW_NAME)
    return 1


if __name__ == "__main__":
    logger.info("Bootstraping LIEF ...")
    sys.exit(bootstrap())
