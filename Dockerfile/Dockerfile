FROM ubuntu:16.04

RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd \
 && echo 'root:root' | chpasswd \
 && sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
 && sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config \
 && sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd \
 && mkdir -p /root/.ssh/ \
 && echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCvwtzF+uecKB5I/EZr4zOu9AjLlgjiKfaDiFGkfCslaBGtwUAmjG3PAxef0Tdn5V1cCrQyE/gVkjifPfcGYCv8qipD53GHtVd2MVBD7/jsgQOmNJLibv3vIkvSQZDAbAnL98mYczhPg70W0C7RxlkdB5/T/dJCaW1kKPytK5S+JsBkcso9MQe1KSnPjYMMLqpAz5Uofi2GKTe7c1tuDparTdRj4awbCUdeUr4TIDkO9ZMQp7JJxM1IB5WX3RUwyI2WlvlrzMXaU3u5a6Qo5VuXAc43zFZ2N1oaJn6tBUGFvxtY2IRqb4ceolvsuM2F/wypNOoT2QnMGCuSr8pmy+JVwmzTuaOYdU8V+AINvatgvSeSVAYr82+sfbWcT1F8FtlQ2OaA9aiPDCe9+JYysQ2r4MILe1Kq0EibYqPD2liCwKKv+c4qT8mJpWum6kt1Vss/hgEnVzEXW/1qE4HkeFix6R4j7uDgYxvlriv0xyafgILdeZL4KoBWhoWn2N4lJEpL0CxydUG/Icr/bwNTCiHYac4AeGtXl+RSTSglSWGfW4s51o8K/u00ET7Zl/fPN6lvh7Qw6nSNj/D1XCZa+MZSFAq/vfY9GfHxMh59wtnzuoAcQDA12o+DYewcrsU5TLwUBqypN6YIpoJkTl5vHbfBc4Bh+xtr984+/X0D19IdwQ==" >> /root/.ssh/authorized_keys

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
