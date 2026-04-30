#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  scripts/aws/create-asterisk-ec2.sh --key-name KEY --ssh-cidr CIDR [options]

Options:
  --region REGION              AWS region. Defaults to AWS config region or us-east-1.
  --key-name KEY               Existing EC2 key pair name.
  --ssh-cidr CIDR              CIDR allowed to SSH, for example 203.0.113.10/32.
  --sip-cidr CIDR              CIDR allowed to SIP/RTP. Defaults to 0.0.0.0/0 for lab testing.
  --instance-type TYPE         Defaults to t3.small.
  --name NAME                  Defaults to nvoip-pabx-test.
  --ami-id AMI                 Optional AMI override. Defaults to latest Ubuntu 22.04 amd64.
  --user-data FILE             Optional cloud-init script override.
  --profile PROFILE            Optional AWS profile.

Creates:
  - security group with SSH, SIP UDP 5060 and RTP UDP 10000-20000
  - one Ubuntu EC2 instance with Asterisk and SIPp installed by cloud-init

The script prints instance id and public IP. Remember to terminate the instance after testing.
EOF
}

region=""
profile=""
key_name=""
ssh_cidr=""
sip_cidr="0.0.0.0/0"
instance_type="t3.small"
name="nvoip-pabx-test"
ami_id=""
user_data_file=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --region) region="$2"; shift 2 ;;
    --profile) profile="$2"; shift 2 ;;
    --key-name) key_name="$2"; shift 2 ;;
    --ssh-cidr) ssh_cidr="$2"; shift 2 ;;
    --sip-cidr) sip_cidr="$2"; shift 2 ;;
    --instance-type) instance_type="$2"; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    --ami-id) ami_id="$2"; shift 2 ;;
    --user-data) user_data_file="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage; exit 1 ;;
  esac
done

[ -n "$key_name" ] || { printf 'Missing --key-name\n' >&2; exit 1; }
[ -n "$ssh_cidr" ] || { printf 'Missing --ssh-cidr\n' >&2; exit 1; }

aws_args=""
if [ -n "$profile" ]; then
  aws_args="$aws_args --profile $profile"
fi

if [ -z "$region" ]; then
  region="$(aws $aws_args configure get region 2>/dev/null || true)"
fi
[ -n "$region" ] || region="us-east-1"
aws_args="$aws_args --region $region"

if [ -z "$ami_id" ]; then
  ami_id="$(aws $aws_args ec2 describe-images \
    --owners 099720109477 \
    --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*' 'Name=state,Values=available' \
    --query 'sort_by(Images,&CreationDate)[-1].ImageId' \
    --output text)"
fi

vpc_id="$(aws $aws_args ec2 describe-vpcs \
  --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' \
  --output text)"

[ "$vpc_id" != "None" ] || { printf 'No default VPC found in %s\n' "$region" >&2; exit 1; }

sg_name="${name}-sg"
sg_id="$(aws $aws_args ec2 describe-security-groups \
  --filters "Name=group-name,Values=$sg_name" "Name=vpc-id,Values=$vpc_id" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || true)"

if [ -z "$sg_id" ] || [ "$sg_id" = "None" ]; then
  sg_id="$(aws $aws_args ec2 create-security-group \
    --group-name "$sg_name" \
    --description "Nvoip PABX test security group" \
    --vpc-id "$vpc_id" \
    --query 'GroupId' \
    --output text)"
fi

authorize_ingress() {
  proto="$1"
  from_port="$2"
  to_port="$3"
  cidr="$4"

  aws $aws_args ec2 authorize-security-group-ingress \
    --group-id "$sg_id" \
    --ip-permissions "IpProtocol=$proto,FromPort=$from_port,ToPort=$to_port,IpRanges=[{CidrIp=$cidr}]" >/dev/null 2>&1 || true
}

authorize_ingress tcp 22 22 "$ssh_cidr"
authorize_ingress udp 5060 5060 "$sip_cidr"
authorize_ingress udp 10000 20000 "$sip_cidr"

if [ -z "$user_data_file" ]; then
  user_data_file="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/user-data-asterisk.sh"
fi

instance_id="$(aws $aws_args ec2 run-instances \
  --image-id "$ami_id" \
  --instance-type "$instance_type" \
  --key-name "$key_name" \
  --security-group-ids "$sg_id" \
  --user-data "file://$user_data_file" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$name},{Key=Project,Value=nvoip-pabx-provisioner}]" \
  --query 'Instances[0].InstanceId' \
  --output text)"

aws $aws_args ec2 wait instance-running --instance-ids "$instance_id"

public_ip="$(aws $aws_args ec2 describe-instances \
  --instance-ids "$instance_id" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)"

cat <<EOF
instance_id=$instance_id
public_ip=$public_ip
security_group_id=$sg_id
region=$region

SSH:
  ssh ubuntu@$public_ip

Next:
  scripts/aws/run-asterisk-test.sh --host $public_ip --key-file /path/to/key.pem --trunk-user USER --trunk-password PASS

Cleanup:
  aws --region $region ec2 terminate-instances --instance-ids $instance_id
EOF
