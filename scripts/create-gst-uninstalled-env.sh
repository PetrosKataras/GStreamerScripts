#!/bin/sh
# ----------------------------------------------------------------------------
#
# create-gst-uninstalled-env.sh
#
# Shell script that creates a complete gst uninstalled setup by setting
# the appropriate env and building gstreamer and plugins through source.
# 
# Type ./create-gst-uninstalled-env.sh --help  for more options.
#
# Based on :
# https://cgit.freedesktop.org/gstreamer/gstreamer/tree/scripts/create-uninstalled-setup.sh
# https://cgit.freedesktop.org/gstreamer/gstreamer/tree/scripts/gst-uninstalled
#
# ----------------------------------------------------------------------------
# 2016 Petros Kataras [ petroskataras gmail com ]
# ----------------------------------------------------------------------------


set -e

OPTS=`getopt -o vhns: --long help,branch:,omx-branch:,skip-depends -n 'parse-options' -- "$@"`

eval set -- "$OPTS"

THIS_DIR=$PWD
HELP=false
BRANCH=master
OMX_BRANCH=master
SKIP_DEPENDENCIES="no"

# Gstreamer and plugins to clone, compile and set the env for.
GST_MODULES="gstreamer gst-plugins-base gst-plugins-good gst-plugins-ugly gst-plugins-bad gst-libav"
# Up until the 1.9 version naming has not been  consistent across gst-omx and the rest of the 
# plugins so we handle it separately.
OMX_MODULE="gst-omx"

# Our uninstalled setup root directory
UNINSTALLED_ROOT=~/gst

help() {
	echo "==========================================================================================="
	echo "This script will create a GStreamer uninstalled setup so that you kind take benefit of "
	echo "latest versions of the library and its plugins without having to install it system wide."
	echo "==========================================================================================="
	echo "Options:"
	echo "--------"
	echo "-h|--help 		Display this message."
	echo "-b|--branch 		GStreamer and plugins branch to set the environment for. Default is master."
	echo "--omx-branch 		GStreamer OMX plugin branch to set the environment for. Default is master."
	echo "--skip-depends 	Skip checking and installing dependencies. Useful after initial run."
	echo "==========================================================================================="
}

while true; do
  case "$1" in
    -h | --help )    help; exit 0;;
    -b | --branch ) BRANCH="$2"; shift; shift ;;
    --omx-branch ) OMX_BRANCH="$2"; shift; shift ;;
    --skip-depends ) SKIP_DEPENDENCIES="yes"; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

COMPILE_FLAGS=""

check_distro() {
	if [ -f /etc/lsb-release ]; then
	    . /etc/lsb-release
	    DISTRO=$DISTRIB_ID
		GST_PLUGINS_BAD_CONFIGURE_FLAGS="--disable-gtk-doc --enable-opengl --enable-glx --enable-x11 --disable-wayland"
	elif [ -f /etc/debian_version ]; then
	    DISTRO=Debian
		DISTRO_ID=$(lsb_release -is)
		if [ "$DISTRO_ID" = "Raspbian" ]; then
			GST_BAD_PLUGINS_CONFIGURE_FLAGS="--disable-gtk-doc --disable-opengl --enable-gles2 --enable-egl --disable-glx --disable-x11 --disable-wayland --enable-dispmanx  --with-gles2-module-name=/opt/vc/lib/libGLESv2.so --with-egl-module-name=/opt/vc/lib/libEGL.so"
			COMPILE_FLAGS='CFLAGS="-I/opt/vc/include -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux/" LDFLAGS="-L/opt/vc/lib'
		fi
	elif [ -f /etc/arch-release ]; then
	    DISTRO=Arch
	elif [ -f /etc/redhat-release ]; then
	    DISTRO="Red Hat"
	else
	    DISTRO=$(uname -s)
	fi
}

install_gst_dependencies_for_distro () {   
	echo "==========================================================================================="
	echo "Installing GStreamer dependencies for Distribution : $DISTRO";
	echo "==========================================================================================="
	if [ "$DISTRO" = "Debian" ] || [ "$DISTRO" = "Ubuntu" ]; then
		sudo apt-get update
		sudo apt-get -y install bison flex git autopoint libtool autoconf liborc-0.4-dev libglib2.0-dev yasm

		# we install standard packages to pull dependencies. Its a bit rough but
		# but works consistently across debian based distros.
		# i.e some fancier methods don't work well with Raspbian.
		sudo apt-get -y install gstreamer1.0-plugins-base \ 
								gstreamer1.0-plugins-good \ 
								gstreamer1.0-plugins-bad \  
								gstreamer1.0-plugins-ugly \
								gstreamer1.0-libav

		if [ "$DISTRIB_ID" = "Raspbian" ]; then
			sudo apt-get -y install gstreamer1.0-omx
		fi
	elif [ "$DISTRO" = "Arch" ]; then
		echo "Arch"
	elif [ "$DISTRO" = "Red Hat" ]; then
	    echo "Red Hat"
	fi
}

# Find where we are running
check_distro

if test "$SKIP_DEPENDENCIES" != "yes"; then
	# Install dependencies. Saves us from missing-plugin pain leter on.
	install_gst_dependencies_for_distro
fi

echo "==========================================================================================="
echo "About to setup uninstalled gst env for branch: $BRANCH";
echo "==========================================================================================="

mkdir -p $UNINSTALLED_ROOT
mkdir -p $UNINSTALLED_ROOT/$BRANCH
mkdir -p $UNINSTALLED_ROOT/$BRANCH/prefix

clone_gst_module () {

	  	git clone git://anongit.freedesktop.org/gstreamer/$1
	  	cd $1
	  	if test "$2" != "master"; then
			git checkout -b $2 origin/$2
	  	fi
	  	git submodule init && git submodule update
		cd ..
}

cd $UNINSTALLED_ROOT/$BRANCH

# Clone gstreamer and plugins.
# gst-omx is handled on its own cause of branch naming-mismatch
for m in $GST_MODULES
do
	clone_gst_module $m $BRANCH
done
if [ "$DISTRO_ID" = "Raspbian" ]; then
	clone_gst_module $OMX_MODULE $OMX_BRANCH
fi

# Create symlink to our uninstalled scipt that sets
# the appropriate gst env for us.
cd $UNINSTALLED_ROOT
ln -s $BRANCH/gstreamer/scripts/gst-uninstalled gst-$BRANCH
chmod +x gst-$BRANCH

compile_gst_module () {
	COMPILE_COMMAND=""
	cd $1
	echo "Configuring and trying to build gst module : $1"
	if test "$1" = "gst-plugins-bad"; then
		COMPILE_COMMAND=''$COMPILE_FLAGS' '$PWD'/autogen.sh '$GST_PLUGINS_BAD_CONFIGURE_FLAGS' && '$UNINSTALLED_ROOT'/gst-'$BRANCH' make -j4'
	elif test "$1" = "gst-omx"; then
		COMPILE_COMMAND=''$COMPILE_FLAGS' '$PWD'/autogen.sh  --disable-gtk-doc --with-omx-target=rpi --with-omx-header-path="/opt/vc/include/IL" && '$UNINSTALLED_ROOT'/gst-'$BRANCH' make -j4' #> $THIS_DIR/compile_gst_omx.sh
	else
		COMPILE_COMMAND=''$PWD'/autogen.sh --disable-gtk-doc && '$UNINSTALLED_ROOT'/gst-'$BRANCH' make -j4'
	fi
	echo $COMPILE_COMMAND > $THIS_DIR/temp-compile-$1.sh
	$UNINSTALLED_ROOT/gst-$BRANCH sh $THIS_DIR/temp-compile-$1.sh
	if test -e $THIS_DIR/temp-compile-$1.sh; then
		echo "Removing temporary compile $1 script..."
		rm $THIS_DIR/temp-compile-$1.sh
	fi
	cd ..
}

cd $BRANCH

# Compile Gstreamer and plugins
for m in $GST_MODULES
do
	compile_gst_module "$m"
done
if [ "$DISTRIB_ID" = "Raspbian" ]; then
	compile_gst_module $OMX_MODULE
fi
