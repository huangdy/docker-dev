# My cool Docker image
# Version 1
# If you loaded redhat-rhel-server-7.0-x86_64 to your local registry, uncomment this FROM line instead:
# FROM registry.access.redhat.com/rhel
# Pull the rhel image from the local registry
# FROM registry.access.redhat.com/rhel
FROM centos:7
# MAINTAINER Daniel Huang

ENV container apacs-dev

# The USER instruction sets the user name (or UID) and optionally the user group (or GID) to use when running the image and for any RUN, CMD and ENTRYPOINT instructions that follow it in the Dockerfile.
USER root
COPY .bashrc .bash_aliases /root/

# COPY redhat.repo /etc/yum.repos.d/

# RUN echo apacs-dev.leidos > /etc/hostname

# Configure to make systemctl works
RUN yum update -y && \
    yum clean all && \
    yum -y install systemd; yum clean all; \
    (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*;\
    m -f /etc/systemd/system/*.wants/*;\
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;\
    rm -f /lib/systemd/system/anaconda.target.wants/*;
    VOLUME [ "/sys/fs/cgroup" ]
CMD ["/usr/sbin/init"]

# install httpd if needed
#RUN yum install -y httpd mod_ssl

# install subversion
RUN yum install -y subversion firewalld

# install JDK 8u291
COPY jdk-8u291-linux-x64.rpm /tmp
RUN cd /tmp && rpm -ivh jdk-8u291-linux-x64.rpm && rm /tmp/jdk-8u291-linux-x64.rpm

# install the Tomcat 9.0.39 as tomcat and tomcat1
ADD apache-tomcat-9.0.39.tar.gz /opt
RUN mv /opt/apache-tomcat-9.0.39 /opt/tomcat
# EXPOSE 8009
ADD apache-tomcat-9.0.39.tar.gz /opt
RUN mv /opt/apache-tomcat-9.0.39 /opt/tomcat1
COPY tomcat.service /etc/systemd/system
COPY tomcat1.service /etc/systemd/system
# RUN systemctl start tomcat tomcat1

# install chrome and chromedriver into /opt/chromedriver/chromedriver
COPY chromedriver /tmp
RUN mkdir /opt/chromedriver && mv /tmp/chromedriver /opt/chromedriver/
COPY google-chrome-stable_current_x86_64.rpm /tmp
RUN yum localinstall -y /tmp/google-chrome-stable_current_x86_64.rpm
RUN yum update -y

# install the ant and maven
ADD apache-ant-1.10.10-bin.tar.gz apache-maven-3.6.3-bin.tar.gz /opt
ENV PATH=/opt/apache-ant-1.10.10/bin:/opt/apache-maven-3.6.3/bin:$PATH
# RUN rm /tmp/apache*

## install oracle 18c
ENV ORACLE_DOCKER_INSTALL=true
COPY oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm oracle-database-xe-18c-1.0-1.x86_64.rpm /tmp/
RUN cd /tmp && \
    yum -y localinstall oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm && \
    yum -y localinstall oracle-database-xe-18c-1.0-1.x86_64.rpm
RUN rm /tmp/oracle*.rpm
RUN (echo "password"; echo "password";) | /etc/init.d/oracle-xe-18c configure
RUN /etc/init.d/oracle-xe-18c start
COPY oratab /etc

USER oracle
RUN mkdir -p /home/oracle/sql/apacs /home/oracle/sql/awm
COPY sql/apacs/* /home/oracle/sql/apacs/
COPY sql/awm/* /home/oracle/sql/awm/
COPY .bashrc .bash_aliases .bash_oracle /home/oracle
RUN source /home/oracle/.bashrc; \
    cd /home/oracle/sql/apacs; sqlplus / as sysdba < fullApacsDatabaseSetup-teamcity.sql; cd /home/oracle/sql/awm; sqlplus / as sysdba < fullAwmDatabaseSetup-18c.sql

# create user apacs
USER root
RUN useradd jenkins

USER jenkins
RUN mkdir /home/jenkins/.m2
COPY .bashrc .bash_aliases /home/jenkins
COPY settings.xml /home/jenkins/.m2
RUN cd /home/jenkins && \
    (echo 'p'; echo 'yes') | svn co --username DanielHuang --password "try!again123" https://apacs-tools.corp.leidos.com/svnrepo/maven_projects/trunk/ workspace && \
    cd /home/jenkins/workspace/custom-datasource-factory; mvn clean install
#    cd /home/jenkins/workspace/apacs-common; mvn clean instal && \
#    cd /home/jenkins/workspace/apacs-server; ant -lib /home/jenkins/.m2/repository/javax/persistence/persistence-api/1.0/persistence-api-1.0.jar -Dconfigfile etc/config/local/jenkins.properties create-local-database && mvn clean install

