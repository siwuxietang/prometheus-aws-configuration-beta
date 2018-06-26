#!/bin/bash
# Attach EBS volume to instance
echo "[$(date '+%H:%M:%S %d-%m-%Y')] installing dependencies for volume attaching"
sudo yum install -y aws-cli wget jq watch

REGION="${region}"
DEVICE="xvdf"

echo "[$(date '+%H:%M:%S %d-%m-%Y')] finding current instance ID"
INSTANCE_ID=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)

echo "[$(date '+%H:%M:%S %d-%m-%Y')] finding volume to attach"
AZ="$(wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zone)"
echo "$VOLUME_ID"
VOLUME_ID="$(aws ec2 describe-volumes --filters Name=availability-zone,Values="$AZ" --volume-ids ${volume_ids} --region "$REGION" --query Volumes[*].VolumeId --output text)"

count=0
DISK_AVAILABILITY="NA"
until [ "$DISK_AVAILABILITY" = available ]; do
    if [[ $count -le 10 ]]
    then
        sleep 10;
        echo "Sleeping for some time"
        count=$((count+1));
        echo "In while loop"
        DISK_AVAILABILITY=$(aws ec2 describe-volumes --region "$REGION" --filters Name=volume-id,Values="$VOLUME_ID" | jq -r '.Volumes[0].State')
    else
        break
    fi
done

case $DISK_AVAILABILITY in
        available)
            aws ec2 attach-volume --volume-id "$VOLUME_ID" --instance-id "$INSTANCE_ID" --device /dev/"$DEVICE" --region "$REGION";
         ;;
        *)
            shutdown -h now;
         ;;
esac

# Waiting for volume to finish attaching
#I do not know why this does not work on the instance
x=0
while [[ $x -lt 15 ]]; do
  if ! [[ -e /dev/$DEVICE ]] ; then
    sleep 1
  else
    break
  fi
  x=$((x+1))
done

# Format and mount volume
if file -s /dev/$DEVICE | grep -q "/dev/$DEVICE: data"; then
  echo "[$(date '+%H:%M:%S %d-%m-%Y')] attach-volume: /dev/$DEVICE does not contain any partition, beginning to format disk"
  mkfs -t ext4 /dev/$DEVICE
else
  echo "[$(date '+%H:%M:%S %d-%m-%Y')] attach-volume: /dev/$DEVICE is already formatted: $(file -s /dev/"$DEVICE")"
fi

#Mount volume to be used by prometheus container
mkdir -p /ecs/prometheus_data
mount /dev/"$DEVICE" /ecs/prometheus_data



#Create prometheus group and allow it to read and write to our volume for storing prometheus data. Note, 65534 is 
#chosen as the UID to be added to the prometheus group as this is the UID that prometheus in the docker container runs as.

groupadd --system --gid 65534 prometheus
useradd --system --uid 65534 --gid 65534 prometheus
chown prometheus:prometheus /ecs/prometheus_data
chmod -R 760 /ecs/prometheus_data

# Set any ECS agent configuration options
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config
yum install -y ecs-init
start ecs
service docker start
