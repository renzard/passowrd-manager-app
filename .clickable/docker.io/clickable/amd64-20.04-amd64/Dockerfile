FROM docker.io/clickable/amd64-20.04-amd64
LABEL base_image_hash="d6f3f655bffe21e490f071e52f62d6480037176ecd2ce07af4a0c26cf7ea9ab0"
ARG GOPATH="/home/renzard/.clickable/go"
ARG SDK_FRAMEWORK="ubuntu-sdk-20.04.1"
ARG CLICK_FRAMEWORK="ubuntu-sdk-20.04.1"
ARG CLICK_FRAMEWORK_BASE="20.04"
ARG APPARMOR_POLICY="20.04"
ARG QT_VERSION="5.12"
ARG ARCH="all"
ARG ARCH_TRIPLET="all"
ARG ARCH_RUST="x86_64-unknown-linux-gnu"
ARG NUM_PROCS="6"
ARG ROOT="/home/renzard/Desktop/passowrd-manager-app-main"
ARG BUILD_DIR="/home/renzard/Desktop/passowrd-manager-app-main/build/all/app"
ARG SRC_DIR="/home/renzard/Desktop/passowrd-manager-app-main"
ARG INSTALL_DIR="/home/renzard/Desktop/passowrd-manager-app-main/build/all/app/install"
ARG CLICK_LD_LIBRARY_PATH="/home/renzard/Desktop/passowrd-manager-app-main/build/all/app/install/lib"
ARG CLICK_PATH="/home/renzard/Desktop/passowrd-manager-app-main/build/all/app/install"
ARG CLICK_QML2_IMPORT_PATH="/home/renzard/Desktop/passowrd-manager-app-main/build/all/app/install/qml"

RUN echo set debconf/frontend Noninteractive | debconf-communicate && echo set debconf/priority critical | debconf-communicate
RUN apt-get update && apt-get install -y --force-yes --no-install-recommends python3-cryptography:all && apt-get clean