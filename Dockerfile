FROM --platform=linux/amd64 archlinux:latest

RUN pacman --noconfirm --needed -Syu

#
# Create builduser for makepkg (which must be run as non root user)
#

RUN pacman --noconfirm --needed -S sudo

RUN useradd --no-create-home --shell=/bin/false builduser && usermod -L builduser
RUN passwd -d builduser # delete the builduser's password
RUN printf 'builduser ALL=(ALL) ALL\n' | tee -a /etc/sudoers # allow the builduser sudo without password

# create the workdir as builduser so builduser has permissions in the workdir
USER builduser
WORKDIR /workdir
USER root

#
# Install riscv-gnu-toolchain (for verilator)
#

## OPTION 1: build
#RUN pacman --noconfirm --needed -S \
#  git \
#  debugedit \
#  fakeroot \
#  binutils
#
#USER builduser
#WORKDIR /workdir/riscv-gnu-toolchain-build
#
## run makepkg as non root user with sudo
#RUN git clone https://aur.archlinux.org/riscv32-gnu-toolchain-elf-llvm-bin.git
#RUN cd riscv32-gnu-toolchain-elf-llvm-bin && sudo -u builduser makepkg --noconfirm -rsi
#RUN rm -rf riscv32-gnu-toolchain-elf-llvm-bin
#
#RUN git clone https://aur.archlinux.org/riscv32-gnu-toolchain-glibc-bin.git
#RUN cd riscv32-gnu-toolchain-glibc-bin && sudo -u builduser makepkg --noconfirm -rsi
#RUN rm -rf riscv32-gnu-toolchain-glibc-bin
#
#RUN git clone https://aur.archlinux.org/riscv64-gnu-toolchain-elf-llvm-bin.git
#RUN cd riscv64-gnu-toolchain-elf-llvm-bin && sudo -u builduser makepkg --noconfirm -rsi
#RUN rm -rf riscv64-gnu-toolchain-elf-llvm-bin
#
#RUN git clone https://aur.archlinux.org/riscv64-gnu-toolchain-glibc-bin.git
#RUN cd riscv64-gnu-toolchain-glibc-bin && sudo -u builduser makepkg --noconfirm -rsi
#RUN rm -rf riscv64-gnu-toolchain-glibc-bin
#
#RUN git clone https://aur.archlinux.org/riscv-gnu-toolchain-bin.git
#RUN cd riscv-gnu-toolchain-bin && sudo -u builduser makepkg -rsi
#RUN rm -rf riscv-gnu-toolchain-bin
#
#USER root
#WORKDIR /workdir
#
#RUN rmdir /workdir/riscv-gnu-toolchain-build
## end of OPTION 1

# OPTION 2: copy /opt/riscv from VM
#
# Run this on the VM:
# $ cp -r /opt/riscv ~/Desktop
# $ cd ~/Desktop
# $ tar cvf riscv.tar.gz riscv
# $ curl bashupload.com -T riscv.tar.gz
# $ rm -rf riscv riscv.tar.gz
#
# Then replace the bashupload URL below
RUN pacman --noconfirm --needed -S wget
WORKDIR /opt
RUN wget https://bashupload.com/BmnzU/riscv.tar.gz
RUN tar xf riscv.tar.gz
RUN rm riscv.tar.gz
WORKDIR /workdir
# end of OPTION 2

ENV PATH="/opt/riscv/bin:${PATH}"

#
# Install verilator
#

RUN pacman --noconfirm --needed -S verilator

#
# Install verible
#

RUN pacman --noconfirm --needed -S wget

RUN wget https://github.com/chipsalliance/verible/releases/download/v0.0-3756-gda9a0f8c/verible-v0.0-3756-gda9a0f8c-linux-static-x86_64.tar.gz
RUN tar xf verible-v0.0-3756-gda9a0f8c-linux-static-x86_64.tar.gz
RUN mv verible-v0.0-3756-gda9a0f8c/bin/* /usr/local/bin
RUN rm -rf verible-v0.0-3756-gda9a0f8c*

#
# Install cs200 VScode extension dependencies
#

RUN pacman --noconfirm --needed -S \
  make \
  python3 \
  cppdap \
  gcc

#
# Clean up
#

RUN pacman --noconfirm -Scc
