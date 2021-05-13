#!/bin/bash

#######################
BASEDIR=$PWD
if [ "$#" -eq 0 ]; then
	echo "Please input a valid .repos file path"
	exit 1;
fi
if [ ! -f "$1" ] || [[ "$1" != *.repos ]]; then
	echo "$1 is not a valid file"
	exit 1
fi
if [ "$#" -eq 2 ]; then
	if [ ! -d "$2" ]; then
	echo "$2 is not a directory"
	exit 1
	else
		echo "Installation set to $2/workspace/ros/aerostack_catkin_ws"
		if [ "$AEROSTACK_WORKSPACE" != "$2"/workspace/ros/aerostack_catkin_ws ] && [ -d "$AEROSTACK_WORKSPACE"/src ] && [[ -f "$AEROSTACK_WORKSPACE"/.catkin_workspace ]]; then 
		echo "Different Aerostack workspace already installed in $AEROSTACK_WORKSPACE/workspace/ros/aerostack_catkin_ws, please remove it or change installation folder"
		exit 1
		fi
	fi
else
	echo "Installation set to $HOME/workspace/ros/aerostack_catkin_ws"
	if [ "$AEROSTACK_WORKSPACE" != "$HOME"/workspace/ros/aerostack_catkin_ws ] && [ -d "$AEROSTACK_WORKSPACE"/src ] && [[ -f "$AEROSTACK_WORKSPACE"/.catkin_workspace ]]; then 
	echo "Different Aerostack workspace already installed in $AEROSTACK_WORKSPACE/workspace/ros/aerostack_catkin_ws, please remove it or change installation folder"
	exit 1
	fi
fi


# Check if dpkg database is locked and ros melodic or ros kinetic is installed
VERSION="$(rosversion -d)"
if [ -z "$VERSION" ];then
	VERSION=$ROS_DISTRO
fi
if [ ! "$VERSION" = 'melodic' ] && [ ! "$ROS_DISTRO" = 'kinetic' ]; then
	if [ -z "$VERSION" ];then
		echo "Ros is not installed"
		exit 1
	fi
	echo "Ros $VERSION is not supported"
	exit 1
fi
sudo apt-get -y install ros-$ROS_DISTRO-mavlink &>/dev/null
if [ "$?" -ne 0 ]; then
	echo $(sudo apt-get --simulate install ros-$ROS_DISTRO-mavlink) &>/dev/null
	if [ "$?" -ne 0 ]; then
		echo "Failed to accept software from packages.ros.org"
	fi
	echo "$(sudo apt-get -y install ros-$ROS_DISTRO-mavlink)"
	echo "Unable to install Aerostack ros dependencies, cancelling installation"
	exit 1
fi

# Absolute path of the aerostack workspace
if [ "$#" -eq 2 ]; then
	AEROSTACK_WORKSPACE="$2/workspace/ros/aerostack_catkin_ws"
else
	AEROSTACK_WORKSPACE="$HOME/workspace/ros/aerostack_catkin_ws"
fi

AEROSTACK_STACK="$AEROSTACK_WORKSPACE/src"
export AEROSTACK_WORKSPACE=$AEROSTACK_WORKSPACE
export AEROSTACK_STACK=$AEROSTACK_STACK

if [[ `lsb_release -rs` == "18.04" ]]; then
	ROS_DISTRO="melodic"
else
	ROS_DISTRO="kinetic"
fi
export ROS_DISTRO=$ROS_DISTRO


echo "------------------------------------------------------"
echo "Obtaining aerostack git info and root source code"
echo "------------------------------------------------------"
mkdir -p $AEROSTACK_WORKSPACE
mkdir -p $AEROSTACK_STACK
cd $AEROSTACK_WORKSPACE/src
vcs import --recursive < "$1"

echo "------------------------------------------------------"
echo "Creating the ROS Workspace"
echo "------------------------------------------------------"

source /opt/ros/$ROS_DISTRO/setup.bash
cd $AEROSTACK_WORKSPACE/src
catkin_init_workspace
cd $AEROSTACK_WORKSPACE
catkin_make

echo "-------------------------------------------------------"
echo "Sourcing the ROS Aerostack WS"
echo "-------------------------------------------------------"
. ${AEROSTACK_WORKSPACE}/devel/setup.bash

echo "-------------------------------------------------------"
echo "Fixing CMakeLists.txt to be able to open QTCreator"
echo "-------------------------------------------------------"
cd $AEROSTACK_WORKSPACE/src
rm CMakeLists.txt
cp /opt/ros/$ROS_DISTRO/share/catkin/cmake/toplevel.cmake CMakeLists.txt

echo "-------------------------------------------------------"
echo "Installing dependencies"
echo "-------------------------------------------------------"
. "$BASEDIR"/install_dependencies.sh
echo "-------------------------------------------------------"
echo "Compiling the Aerostack"
echo "-------------------------------------------------------"
cd ${AEROSTACK_WORKSPACE}
[ ! -f "$AEROSTACK_STACK/behaviors/behavior_packages/multi_sensor_fusion" ] && touch "$AEROSTACK_STACK/behaviors/behavior_packages/multi_sensor_fusion/CATKIN_IGNORE"
catkin_make

[ -f "$AEROSTACK_STACK/behaviors/behavior_packages/multi_sensor_fusion/CATKIN_IGNORE" ] && rm "$AEROSTACK_STACK/behaviors/behavior_packages/multi_sensor_fusion/CATKIN_IGNORE"
catkin_make -j1

grep -q "source $AEROSTACK_WORKSPACE/devel/setup.bash" $HOME/.bashrc || echo "source $AEROSTACK_WORKSPACE/devel/setup.bash" >> $HOME/.bashrc
sed -i '/export AEROSTACK_STACK/d' $HOME/.bashrc && echo "export AEROSTACK_STACK=$AEROSTACK_WORKSPACE/src/aerostack_stack" >> $HOME/.bashrc
sed -i '/export AEROSTACK_WORKSPACE/d' $HOME/.bashrc && echo "export AEROSTACK_WORKSPACE=$AEROSTACK_WORKSPACE" >> $HOME/.bashrc
sed -i '/export LD_LIBRARY_PATH/d' $HOME/.bashrc && echo "export LD_LIBRARY_PATH=$AEROSTACK_WORKSPACE/devel/lib:/opt/ros/$ROS_DISTRO/lib:$AEROSTACK_WORKSPACE/devel/lib/parrot_arsdk" >> $HOME/.bashrc
