FROM nvidia/cudagl:10.0-devel-ubuntu16.04

################################## PACKAGE ##################################

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN apt-get -o Acquire::ForceIPv4=true update && apt-get -yq dist-upgrade \
 && apt-get -o Acquire::ForceIPv4=true install -yq --no-install-recommends \
	locales cmake git build-essential apt-transport-https python-dev \
        python-pip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

##################################### PIP ######################################

RUN pip install --upgrade pip setuptools && pip install --upgrade 'setuptools<45.0.0'

RUN pip install  numpy \
    matplotlib \
    pandas \
    jupyter

###################################### CUDNN ###################################

ENV CUDNN_VERSION 7.4.1.5
LABEL com.nvidia.cudnn.version="${CUDNN_VERSION}"

RUN apt-get update && apt-get install -y --no-install-recommends lsb-release\
            libcudnn7=$CUDNN_VERSION-1+cuda10.0 \
            libcudnn7-dev=$CUDNN_VERSION-1+cuda10.0 && \
    apt-mark hold libcudnn7 

################################### INSTALL ROS ################################

RUN  sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list' && \
	apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654 && \
	apt-get update && \
	apt-get install -y --no-install-recommends ros-kinetic-desktop-full python-rosdep && \
	rosdep init && \
	rosdep update

################################## SETUP USER ##################################

ENV SHELL=/bin/bash \
	USER=cssp \
	UID=1000 \
	LANG=en_US.UTF-8 \
	LANGUAGE=en_US.UTF-8

ENV HOME=/home/${USER}

RUN adduser --disabled-password \
	--gecos "Default user" \
	--uid ${UID} \
	${USER} 

RUN echo "root:root" | chpasswd
RUN echo "${USER}:cssp" | chpasswd


# setup entrypoint
COPY ./ros_entrypoint.sh /

ENTRYPOINT ["/ros_entrypoint.sh"]

#################################### CATKIN ####################################

RUN mkdir -p ${HOME}/catkin_ws/src 

RUN cd ${HOME}/catkin_ws \
 && apt-get -o Acquire::ForceIPv4=true update \
 && apt-get -o Acquire::ForceIPv4=true install -y vim nano gedit git \
 && /bin/bash -c "source /opt/ros/kinetic/setup.bash && rosdep update && rosdep install --as-root apt:false --from-paths src --ignore-src -r -y" \
 && apt-get clean \
 && /bin/bash -c "source /opt/ros/kinetic/setup.bash && catkin_make"

RUN echo "source ~/catkin_ws/devel/setup.bash" >> ${HOME}/.bashrc


##################################### TAIL #####################################
RUN chown -R ${UID} ${HOME}/
RUN echo "cssp ALL=(ALL)  ALL" > /etc/sudoers

# Support of nvidia-docker 2.0
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

 
USER ${USER}

WORKDIR ${HOME}/catkin_ws
