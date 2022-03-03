#!/usr/bin/env bash

# 刷新环境变量
source /etc/profile
source $HOME/.bash_profile

#====================== 初始参数 =========================
# 项目信息
dirName='blog-1/blog-springboot'
appName='blog-1'
port=9090

#======================= 工具方法 ========================

# 自动stash，如果存在更改的内容
function autoStash() {
  if [ "$(git status --porcelain | wc -l)" -gt 0 ]
  then
    git stash save "auto stash at: $(date)"
  fi
}

## 非阻塞延迟2-3秒
function delay() {
  echo "loading..."
  ti1=$(date +%s)    #获取时间戳
  ti2=$ti1
  while [[ "$((ti2 - ti1 ))" -le 5 ]]
  do
	  ti2=$(date +%s)
  done
}

#======================================================
#     start to run application
#
#   usage: run.sh [-b branch_name] [-p profile_name]
#
#    -b 分支名称：默认为当前分支
#    -p profile: 默认为default
#
#======================================================

# 参数解析
while getopts "b:p:" opt
do
    case $opt in
      b)
        branch_name=$OPTARG
            ;;
      p)
        profile_name=$OPTARG
            ;;
      ?)
        echo "未识别的参数"
        exit 1
        ;;
    esac
done

# 目录检测
if ! cd /projects/${dirName}
then
  echo "${dirName} 不存在, 项目启动失败"
  exit 1
fi

# 自动stash
autoStash

# 将关闭旧服务的逻辑提前到打包，节省服务器资源
# 根据端口号查询对应的pid，并删除服务进程
pid=$(netstat -nlp | grep :$port | awk '{print $7}' | awk -F"/" '{ print $1 }');
if [  -n  "$pid"  ];  then
echo "old ${appName} services pid: $pid"
    kill  -9  "$pid";
fi

# 尝试关闭其它未监听到的同个服务
pid2=$(pgrep -f "${appName}.jar")
if [  -n  "$pid2"  ];  then
echo "old ${appName} services pid(not listen ${port}): $pid2"
    kill  -9  "$pid2";
fi

# 支持外部传递分支名称，没有则按当前默认分支处理
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ -n "$branch_name" ] && [ "$branch_name" != "${current_branch}" ]
then
  git checkout "$branch_name"
  git pull origin "$branch_name"
else
  git pull origin "${current_branch}"
fi

# 打包，跳过UT和DOC
mvn clean package -DskipTests -Dmaven.javadoc.skip=true -Dmaven.springboot.skip=false

# 删除老文件，复制新文件
rm /data/app/$appName.jar -f
rm /data/logs/$appName.log -f
mv ./target/app.jar /data/app/$appName.jar

# 确认profile参数,默认为default
if [ -z "$profile_name" ]; then profile_name='default'; fi

# 启动项目
cd /data/app|| exit
nohup java -jar -Dspring.cloud.config.enabled=false -Dspring.profiles.active=${profile_name} -Xms512m -Xmx512m \
 /data/app/$appName.jar > /data/logs/$appName.log 2>&1 &

# 添加一点延迟，等待日志文件创建，避免tail失败
delay

keywords="Started [A-Za-z0-9]\+Application in"
log_file="/data/logs/$appName.log"
{ sed /"$keywords"/q; kill $!; } < <(exec timeout 1.5m tail -Fn 0 "$log_file")
