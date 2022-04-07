# FROM ubuntu:18.04
FROM nvidia/cuda:11.6.1-cudnn8-devel-ubuntu20.04
# FROM phusion/baseimage

##################################################################
# This whole section is for mpirun. Do not touch until necessary #
##################################################################
ENV USER mpirun

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/home/${USER} 


RUN apt-get update -y && \
    apt-get install -y --no-install-recommends sudo apt-utils && \
    apt-get install -y --no-install-recommends openssh-server \
        python3-dev python3-numpy python3-pip python3-virtualenv python3-scipy \
        gcc gfortran libopenmpi-dev openmpi-bin openmpi-common openmpi-doc binutils \
        curl wget git python3-setuptools libx11-dev ffmpeg libsm6 libxext6 && \
    apt-get clean && apt-get purge && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir /var/run/sshd
RUN echo 'root:${USER}' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# ------------------------------------------------------------
# Add an 'mpirun' user
# ------------------------------------------------------------

RUN adduser --disabled-password --gecos "" ${USER} && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ------------------------------------------------------------
# Set-Up SSH with our Github deploy key
# ------------------------------------------------------------

ENV SSHDIR ${HOME}/.ssh/

RUN mkdir -p ${SSHDIR}

ADD ssh/config ${SSHDIR}/config
ADD ssh/id_rsa.mpi ${SSHDIR}/id_rsa
ADD ssh/id_rsa.mpi.pub ${SSHDIR}/id_rsa.pub
ADD ssh/id_rsa.mpi.pub ${SSHDIR}/authorized_keys

RUN chmod -R 600 ${SSHDIR}* && \
    chown -R ${USER}:${USER} ${SSHDIR}

RUN sudo -H python3 -m pip install --upgrade pip

USER ${USER}
RUN  sudo -H python3 -m pip install --user -U setuptools \
    && sudo -H python3 -m pip install --user mpi4py

# ------------------------------------------------------------
# Configure OpenMPI
# ------------------------------------------------------------

USER root

RUN rm -fr ${HOME}/.openmpi && mkdir -p ${HOME}/.openmpi
ADD default-mca-params.conf ${HOME}/.openmpi/mca-params.conf
RUN chown -R ${USER}:${USER} ${HOME}/.openmpi

# ------------------------------------------------------------
# Copy MPI4PY example scripts
# ------------------------------------------------------------

ENV TRIGGER 1

ADD mpi4py_benchmarks ${HOME}/mpi4py_benchmarks
RUN chown -R ${USER}:${USER} ${HOME}/mpi4py_benchmarks

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
##################################################################
#                      mpirun section ends                       #
##################################################################

# ------------------------------------------------------------
# My own setups
# ------------------------------------------------------------

# Install zsh and OMzsh
RUN apt-get update -y
RUN apt-get install -yq zsh
RUN chsh -s $(which zsh)
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.2/zsh-in-docker.sh)" -- \
    -t tjkirch

# Install conda
RUN curl -LO "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
RUN bash Miniconda3-latest-Linux-x86_64.sh -p /miniconda -b
RUN rm Miniconda3-latest-Linux-x86_64.sh
ENV PATH=/miniconda/bin:${PATH}
RUN conda update -y conda
RUN conda init zsh

#ENTRYPOINT ["/bin/zsh"]
#CMD ["bash"]
CMD [ "zsh" ]