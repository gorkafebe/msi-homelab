# garmin-login: one-shot container for the FIRST login (docs/GARMIN.md).
# garminconnect 0.3.20 and its dependencies are installed from
# requirements.txt, where every package is pinned with sha256 hashes
# (pip --require-hashes refuses anything else).
#
# requirements.txt was generated from requirements.in with:
#   uv pip compile --generate-hashes --python-version 3.13 \
#     --python-platform x86_64-manylinux_2_28 --no-header requirements.in -o requirements.txt
# (uv 0.6.17 image, pinned in stacks/garmin/fetcher/Dockerfile). x86_64 only.

FROM python:3.13.18-slim-bookworm@sha256:f0fa218d5b06f9b9235024fa061cde2cb141f726de52134471053d2d9b5324a3
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
COPY requirements.txt /tmp/requirements.txt
RUN pip install --require-hashes --only-binary=:all: -r /tmp/requirements.txt \
 && groupadd --gid 1000 appuser \
 && useradd --uid 1000 --gid appuser --shell /usr/sbin/nologin --no-create-home appuser \
 && install -d -m 700 -o appuser -g appuser /tokens \
 && install -d -m 755 /app
# (--chmod on COPY would also apply to a parent folder it has to create, which
# is why /app is created above with its own mode.)
COPY --chmod=644 login.py /app/login.py
USER appuser
WORKDIR /app
ENTRYPOINT ["python", "-I", "/app/login.py"]
