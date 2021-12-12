#!/bin/bash

# box86-deb.sh: generate a box86 deb file for easy system installation

NOWDAY="$(printf '%(%Y-%m-%d)T\n' -1)"

if ! command -v checkinstall > /dev/null; then
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

#clone box86 using git
cd $HOME || error "Failed to enter $HOME directory!"
rm -rf box86
git clone https://github.com/ptitSeb/box86 || error "Failed to clone box86!"
cd box86 && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DARM_DYNAREC=1 || error "Failed to run cmake."
make -j4 || error "Failed to run make."

#this function gets the box86 version and commit when it's needed. (Thanks Itai)
function get-box86-version() {
	if [[ $1 == "ver" ]]; then
		BOX86VER="$(./box86 -v | grep box86 | cut -c 21-25)"
	elif [[ $1 == "commit" ]]; then
		BOX86COMMIT="$(./box86 -v | tail -n +2 | cut -c27-34)"
	fi
}

#create docs package, postinstall and description
mkdir doc-pak
cp $HOME/box86/docs/README.md $HOME/box86/build/doc-pak || warning "Failed to add readme to docs"
cp $HOME/box86/docs/CHANGELOG.md $HOME/box86/build/doc-pak || warning "Failed to add changelog to docs"
cp $HOME/box86/docs/USAGE.md $HOME/box86/build/doc-pak || warning "Failed to add USAGE to docs"
cp $HOME/box86/LICENSE $HOME/box86/build/doc-pak || warning "Failed to add license to docs"
echo "box86 lets you run x86 Linux programs (such as games) on non-x86 Linux systems, like ARM (host system needs to be 32bit little-endian)">description-pak || error "Failed to create description-pak."
echo "#!/bin/bash
echo 'Restarting systemd-binfmt...'
systemctl restart systemd-binfmt || true">postinstall-pak || error "Failed to create postinstall-pak!"
get-box86-version ver && get-box86-version commit || error "Failed to get box86 version or commit!"
DEBVER="$(echo "$BOX8686VER+$(date +"%F" | sed 's/-//g').$BOX86COMMIT")" || error "Failed to set debver variable."
sudo checkinstall -y -D --pkgversion="$DEBVER" --arch="armhf" --provides="box86" --conflicts="qemu-user-static" --pkgname="box86" --install="no" make install || error "Checkinstall failed to create a deb package."

# move deb to destination folder
echo "Moving deb to ${HOME}..."
mv $HOME/box86/build/box86*.deb $HOME || error "Failed to move deb."
cd $HOME
rm -rf box86 || error "Failed to remove box86 folder."
