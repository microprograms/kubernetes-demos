# 基础镜像
FROM geoffh1977/chrony:amd64

# 修改时区
RUN apk add --no-cache tzdata && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" > /etc/timezone