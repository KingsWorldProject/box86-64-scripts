#!/bin/bash

# box64-deb.sh: generate a box64 deb file for easy system installation

NOWDAY="$(printf '%(%Y-%m-%d)T\n' -1)"

if ! command -v checkinstall > /dev/null; then
  echo "checkinstall not found (needed for initial deb creation)"
  echo "installing it now..."
  #this package contains everything that's needed for checkinstall
  sudo apt update && sudo apt install gettext -y || error "Failed to apt update && apt install gettext"
  git clone https://github.com/giuliomoro/checkinstall
  cd checkinstall
  sudo make install
  cd .. && rm -rf checkinstall
fi

#error function: prints error in red, touches log and exits
function error() {
    echo -e "\e[91m$1\e[0m" 1>&2
    exit 1
}

#warning function: prints error in yellow, touches log and continues (thanks Itai)
function warning() {
	echo -e "$(tput setaf 3)$(tput bold)$1$(tput sgr 0)"
}

printf "Checking if you are online..."
wget -q --spider http://github.com
if [ $? -eq 0 ]; then
  echo "Online. Continuing."
else
  error "Offline. Connect to the internet then run the script again. (could not resolve github.com)"
fi

#clone box64 using git
cd $HOME || error "Failed to enter $HOME directory!"
rm -rf box64
git clone https://github.com/ptitSeb/box64 || error "Failed to clone box64!"
cd box64 && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DARM_DYNAREC=1 || error "Failed to run cmake."
make -j4 || error "Failed to run make."

#this function gets the box64 version and commit when it's needed. (Thanks Itai)
function get-box64-version() {
	if [[ $1 == "ver" ]]; then
		BOX64VER="$(./box64 -v | grep Box64 | cut -c 21-25)"
	elif [[ $1 == "commit" ]]; then
		BOX64COMMIT="$(./box64 -v | tail -n +2 | cut -c27-34)"
	fi
}

#create docs package, postinstall and description
mkdir doc-pak
cp $HOME/box64/docs/README.md $HOME/box64/build/doc-pak || warning "Failed to add readme to docs"
cp $HOME/box64/docs/CHANGELOG.md $HOME/box64/build/doc-pak || warning "Failed to add changelog to docs"
cp $HOME/box64/docs/USAGE.md $HOME/box64/build/doc-pak || warning "Failed to add USAGE to docs"
cp $HOME/box64/LICENSE $HOME/box64/build/doc-pak || warning "Failed to add license to docs"
echo "Box64 lets you run x86_64 Linux programs (such as games) on non-x86_64 Linux systems, like ARM (host system needs to be 64bit little-endian)">description-pak || error "Failed to create description-pak."
echo "#!/bin/bash
echo 'Restarting systemd-binfmt...'
systemctl restart systemd-binfmt || true">postinstall-pak || error "Failed to create postinstall-pak!"
get-box64-version ver && get-box64-version commit || error "Failed to get box64 version or commit!"
DEBVER="$(echo "$BOX64VER+$(date +"%F" | sed 's/-//g').$BOX64COMMIT")" || error "Failed to set debver variable."
sudo checkinstall -y -D --pkgversion="$DEBVER" --arch="arm64" --provides="box64" --conflicts="qemu-user-static" --pkgname="box64" --install="no" make install || error "Checkinstall failed to create a deb package."

mv box64*.deb sample.deb
dpkg-deb -R sample.deb box64-deb
rm -f sample.deb
rm box64-deb/DEBIAN/control
echo "Package: box64
Priority: extra
Section: utils
Maintainer: Ryan Fortner <ryankfortner@gmail.com>
Architecture: armhf
Version: ${DEBVER}
Provides: box64
Conflicts: qemu-user-static
Description: Box64 lets you run x86_64 Linux programs (such as games) on non-x86_64 Linux systems, like ARM (host system needs to be 64bit little-endian)" > box64-deb/DEBIAN/control
dpkg-deb -b box64-deb/ box64_${DEBVER}_arm64.deb

# move deb to destination folder
echo "Moving deb to ${HOME}..."
mv $HOME/box64/build/box64*.deb $HOME || error "Failed to move deb."
cd $HOME
rm -rf box64 || error "Failed to remove box64 folder."
