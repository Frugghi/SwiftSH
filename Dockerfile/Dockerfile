FROM alpine:3.6

RUN apk add --no-cache openssh bash
RUN ssh-keygen -A \
 && sed -i s/#PermitRootLogin.*/PermitRootLogin\ yes/ /etc/ssh/sshd_config \
 && echo "root:root" | chpasswd

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
