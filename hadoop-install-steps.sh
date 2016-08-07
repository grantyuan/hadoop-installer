#!/bin/sh
if [ '$1' == '' ] || [ '$2' == '' ] 
then
    echo "usage:"
    echo "hadoop-installer.sh YouMachineName MasterName"
    exit
fi

MachineName=$1
# rename current machine
echo $MachineName>/etc/hostname

Master=$2
UserDir=/home/$USER/
HadoopTempDir=$UserDir/dadoop/
HadoopZipFileName=hadoop.tar.gz
HadoopDownloadUrl="https://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-2.6.4/hadoop-2.6.4.tar.gz"

[[ -d $HadoopTempDir ]] || mkdir $HadoopTempDir

pusdd $HadoopTempDir\

if ! [[ -f $HadoopZipFileName ]]; then
    #download hadoop
    echo 'not found hadoop installer, start to downloading ...'

    wget $HadoopDownloadUrl $HadoopZipFileName    
fi

[[ -f $(pwd)/$HadoopZipFileName ]] && tar -xf $HadoopZipFileName

#create user hadoop
getent passwd hadoop > /dev/null 2>&1
if[ $? -ne 0 ]; then 
addgroup hadoop
adduser hadoop -ingroup hadoop hadoop

password=0
password1=1

while $passwd != $password1 
do
    echo "input password for hadoop:"
    read -s password
    echo "please confirm:"
    read -s password1

    if $passwd == $password1 ; then
    echo "password confirmation is failed, please try again."
    fi
done
 
passwd hadoop $passwd

#   grant access right for hadoop
cat /etc/sudoers | grep hadoop > /dev/null 2>&1

if[ $? == 1 ] ; then
# add "hadoop  ALL=(ALL:ALL) ALL" to file /etc/sudoers
sed -i '/root	ALL=(ALL:ALL) ALL/a \
hadoop  ALL=(ALL:ALL) ALL\
' /etc/sudoers
fi

IfProcessInstalled(){
    type $1 > /dev/null 2>&1
    return $?
}


# java versoin check func
CheckJavaVersion(){
    IfProcessInstalled java

    if [ $? ] ; then
    # check java versoin
    java -version 2>&1 | grep '1.7\|1.8\|1.9' > /dev/null 2>&1
    if [ $? == 0 ]; then return 0; else return 1; fi
}

CheckJavaVersion

if [ !$? ]; then
# uninstall java
apt-get  purge java*

# install jdk
jdknotOk=true

while [ '$jdknotOk'=true ] 
do
    echo "please download the jdk to current location, after downloading jdk to $(pwd), press Y to continue:"
    read line
    
    if [ line != 'y']; then
    continue
    fi

    # check jdk installation package
    jdkfileName=$(find jdk* 2>&1 | grep -m 1 'jdk.*.tar.gz' 2>&1)

    if[[ $jdkfileName != "jdk*.tar.gz" ]]; then
    # ask for jdk installation package
        continue
    else
        $jdknotOk=false                    
    fi
done

tar -xf $jdkfileName jdk
# $jdkfileName
mkdir usr/lib/jvm
mv jdk /usr/lib/jvm/jdk

if [ $? == 0 ]; then 
# config java


    export JRE_HOME=$JAVA_HOME/jre
    export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib

    javaConfig=$(cat /etc/profile | grep JAVA_HOME 2>&1)

    # backup /etc/profile
    time=$(date +'%m-%d-%Y_%h-%M-%s') 
    cp /etc/profile '/etc/profile_bk_$time'

    if [ '$javaConfig' == *'JAVA_HOME'* ]
    then
        # replace the new javahome
        sed 's/export.*JAVA_HOME=.*'/'export JAVA_HOME=\/usr\/lib\/jvm\/jdk/g' /etc/profile
        # sed 's/export.*JAVA_HOME=.*'/'export JAVA_HOME=\/usr\/lib\/jvm\/jdk/g' /home/hadoop/.bashrc
        else
        # append java config
        echo 'export JAVA_HOME=/usr/lib/jvm/jdk/' >> /etc/profile
        echo 'export JRE_HOME=$JAVA_HOME/jre' >> /etc/profile
        echo 'export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib' >> /etc/profile
    fi

    source /etc/profile

    update-alternatives --install "/usr/bin/java" "java" "$JAVA_HOME/bin/java" 1
    update-alternatives --install "/usr/bin/javac" "javac" "$JAVA_HOME/bin/javac" 1
    update-alternatives --install "/usr/bin/javaws" "javaws" "$JAVA_HOME/bin/javaws" 1
    update-alternatives --set java $JAVA_HOME/bin/java
    update-alternatives --set javac $JAVA_HOME/bin/javac
    update-alternatives --set javaws $JAVA_HOME/bin/javaws

    # check java installation
    CheckJavaVersion

    if [ $? == 1 ]; then
        echo "Failed to install jdk">&2
        exit $?
    fi
fi

# install hadoop
echo starting to install hadoop

tar -xf $HadoopZipFileName -C /usr/local
mv /usr/local/$HadoopZipFileName ./hadoop
chown -R hadoop:hadoop ./hadoop

# check version 
/usr/local/hadoop/bin/hadoop version >/dev/null 2>&1

if ! [ $? ] ; then echo "Error unable to run hadoop version" > &2 ; exit; fi 

# change /usr/local/hadoop/etc/hadoop/hadoop_env.sh 
# change the evn variable for hadoop_env.sh
sed "s/.*JAVA_HOME=.*//g" /usr/local/hadoop/etc/hadoop/hadoop_env.sh
sed "s/export.*HADOOP_CONF_DIR=.*/export HADOOP_CONF_DIR=/usr/local/hadoop/conf/"
sed "s/export.*HADOOP_OPTS=.*/export HADOOP_OPTS=-Djava.net.preferIPv4Stack=true"

cat /etc/profile | grep 'HADOOP_INSTALL' > /dev/null 2>&1
if [ $? ] ; then
    sed "s/.*HADOOP.*//g" 
    sed "s/export .*HADOOP_INSTALL.*//g"
    sed "s/export .*HADOOP_HOME.*//g"
fi

echo '#HADOOP\
export HADOOP_HOME=/usr/local/hadoop/\
export HADOOP_INSTALL=$HADOOP_HOME\
export PATH=$PATH:$HADOOP_INSTALL/bin\
export PATH=$PATH:$HADOOP_INSTALL/sbin\
export HADOOP_MAPRED_HOME=$HADOOP_INSTALL\
export HADOOP_COMMON_HOME=$HADOOP_INSTALL\
export HADOOP_HDFS_HOME=$HADOOP_INSTALL\
export YARN_HOME=$HADOOP_INSTALL\
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_INSTALL/lib/native\
export HADOOP_OPTS="-Djava.library.path=$HADOOP_INSTALL/lib"\
#HADOOP VARIABLES END\
' >> /dev/profile

source /dev/profile

# input master and slave ip
echo "please input the map for ip and hostname: [press Y to input, press any other key to cancel input]?"
read input

allSlaves=()
if [ '$input' == 'y' ]; then 

    echo "please input master ip:"
    read masterIp
    echo '$masterIp $Master' >> /etc/hosts
    local count=0
    while [ '$input' == 'y' ] 
    do
        echo "please input the ip and host for slave, like \
            192.168.0.1 slave1"
        
        read -a maping
        echo ${maping[0]} ${maping[1]} >> /etc/hosts
        allSlaves[$count]=${maping[1]}
        let 'count++'
        echo "input more? press [Yes/No]"
        read input
        if [ '$input' == 'n' ] 
        then
            break 
        fi
    done
fi

# require $1, $1 should be the user
SwithUser(){
    if [ $? ] ; then
        echo "Please input hadoop password to swith current user to Hadoop:"
        su $1
        local retry=0
        while ! [ $? ] 
        do
            echo "Please input hadoop password to swith current user to Hadoop:"
            su $1
            if ! [ $? ] ; then
                let 'retry++'
                
                echo "please retry! max retry times 3, now has $retry times"
                if [ retry >= 3] ; then exit ; fi    
            fi
        done
    else
        echo "Error, unable to install ssh server, please do it manually" >&2
        exit
    fi
}

# install ssh
# config ssh no password login

if ! [[ -f /etc/init.d/ssh ]] ; then
    apt-get install openssh-clients
    apt-get install openssh-server
    if ! [ $? ] ; then exit; fi

fi

# swith current user to hadoop
SwithUser hadoop

# start install ssh 
pushd /home/hadoop/.ssh/
rm ./id_rsa* 
# create ssh key 
ssh-keygen -t rsa
# todo check if the key has been created succssfully
cat id_rsa.pub  >> authorized_keys

chmod 600 authorized_keys

/etc/init.d/ssh restart

# todo copy pub key to master/slaves

installSSHCert(){
    echo "install ssh cert to machine $1"

    local SCRIPT='cat ~/id_rsa.pub >> ~/.ssh/authorized_keys \
    chmod 600 authorized_keys
    /etc/init.d/ssh restart    
    '

    scp ~/.ssh/id_rsa.pub "hadoop@$1:/home/hadoop/"
    ssh hadoop@$1 "${SCRIPT}"

}

# scp
if ! [ '$Master' == '$MachineName' ]; then
    installSSHCert $Master
fi

for machineItem in ${allSlaves[@]}
do
    if ! [ '$MachineName' == '$machineItem' ]; then 
        continue
    fi
    
    installSSHCert  $machineItem
    # scp ~/.ssh/id_rsa.pub "hadoop@$machineItem:/home/hadoop/"
    # echo 'You has to run \ 
    #  cat ~/id_rsa.pub >> ~/.ssh/authorized_keys \
    #  in machine $machineItem !!!'
done

popd
# end install ssh

# start config hadoop 

coresiteconfig='\
<?xml version="1.0" encoding="UTF-8"?>\
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>\
<configuration>\
   <property> \
      <name>fs.default.name</name> \
      <value>hdfs://$Master:9000/</value>\ 
   </property> \   
   <property> \
      <name>dfs.permissions</name>\ 
      <value>false</value>\ 
   </property> \
</configuration>\
'
cp ${HADOOP_HOME:-'/usr/local/hadoop/'}etc/hadoop/core-site.xml ${HADOOP_HOME:-'/usr/local/hadoop/'}etc/hadoop/core-site_bk.xml
echo $coresiteconfig > ${HADOOP_HOME:-'/usr/local/hadoop/'}etc/hadoop/core-site.xml

hdfssiteconfig='\
<?xml version="1.0" encoding="UTF-8"?>\
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>\
<configuration>\
<property>\
      <name>dfs.replication</name>\
      <value>1</value>\
   </property>\    
   <property>\
      <name>dfs.name.dir</name>\
      <value>file:///home/hadoop/hadoopinfra/hdfs/namenode </value>\
   </property>\    
   <property>\
      <name>dfs.data.dir</name>\ 
      <value>file:///home/hadoop/hadoopinfra/hdfs/datanode </value>\ 
   </property>\
</configuration>\
'

cp ${HADOOP_HOME:-'/usr/local/hadoop/'}etc/hadoop/hafs-site.xml ${HADOOP_HOME:-'/usr/local/hadoop/'}etc/hadoop/hdfs-site_bk.xml
echo $coresiteconfig > ${HADOOP_HOME:-'/usr/local/hadoop/'}etc/hadoop/hdfs-site.xml

mapredsiteconfig='\
<?xml version="1.0"?>\
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>\
<configuration>\
<property> \
      <name>mapreduce.framework.name</name>\
      <value>yarn</value>\
   </property>\
<property> \
      <name>mapred.job.tracker</name>\
      <value>$Master:9001</value>\
   </property>\
</configuration>\
'

cp ${HADOOP_HOME:-'/usr/local/hadoop/'}etc/hadoop/mapred-site.xml ${HADOOP_HOME:-'/usr/local/hadoop/'}etc/hadoop/mapred-site_bk.xml
echo $coresiteconfig > ${HADOOP_HOME:-'/usr/local/hadoop/'}etc/hadoop/mapred-site.xml

# end config hadoop
popd

# start hadoop
echo "Hadoop has been installed!!!! please try to start master machine: $Master"