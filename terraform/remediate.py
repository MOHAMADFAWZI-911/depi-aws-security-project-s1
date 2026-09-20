import json
import boto3
import os

ec2 = boto3.client('ec2')
sns = boto3.client('sns')
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    try:
        detail = event.get('detail', {})
        req_params = detail.get('requestParameters', {})
        group_id = req_params.get('groupId')
        ip_permissions = req_params.get('ipPermissions', {})

        if not group_id or not ip_permissions:
            return

        # CloudTrail logs represent ipPermissions as a list under 'items'
        items = ip_permissions.get('items', [])
        
        for item in items:
            from_port = item.get('fromPort')
            to_port = item.get('toPort')
            ip_ranges = item.get('ipRanges', {}).get('items', [])
            
            # Check if ports 22 or 3389 are affected
            if from_port in [22, 3389] or to_port in [22, 3389]:
                for ip in ip_ranges:
                    if ip.get('cidrIp') == '0.0.0.0/0':
                        
                        # Revoke the dangerous rule
                        ec2.revoke_security_group_ingress(
                            GroupId=group_id,
                            IpPermissions=[item]
                        )
                        
                        # Publish alert to SNS
                        sns.publish(
                            TopicArn=SNS_TOPIC_ARN,
                            Message=f"Auto-remediation triggered: Removed 0.0.0.0/0 rule for port {from_port} on Security Group {group_id}.",
                            Subject="Security Alert: Open Port Removed"
                        )
                        print(f"Successfully removed 0.0.0.0/0 rule for port {from_port} on {group_id}")
    except Exception as e:
        print(f"Error during remediation: {str(e)}")