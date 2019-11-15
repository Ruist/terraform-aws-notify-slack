from __future__ import print_function

import base64
import json
import logging
import os

import boto3
import urllib.parse
import urllib.request


# Decrypt encrypted URL with KMS
def decrypt(encrypted_url):
    region = os.environ['AWS_REGION']
    try:
        kms = boto3.client('kms', region_name=region)
        plaintext = kms.decrypt(CiphertextBlob=base64.b64decode(encrypted_url))[
            'Plaintext']
        return plaintext.decode()
    except Exception:
        logging.exception("Failed to decrypt URL with KMS")


def ec2_notification(message, region, environment):
    return {
        "fallback": "EC2 Instance Terminated in {0}: {1}".format(region,
                                                                 message[
                                                                     "detail"][
                                                                     "instance-id"]),
        "fields": [
            {"title": "Instance", "value": message["detail"]["instance-id"],
             "short": True},
            {"title": "Region", "value": region, "short": True},
            {"title": "Environment", "value": environment, "short": True}
        ]
    }


def guardduty_notification(message, region, environment):
    return {
        "fallback": "GuardDuty finding in {0} first seen at {1}: {2} {3}".format(
            region, message["detail"]["service"]["eventFirstSeen"],
            message["detail"]["title"], message["detail"]["description"]),
        "fields": [
            {"title": "Title",
             "value": message["detail"]["title"],
             "short": False},
            {"title": "Description", "value": message["detail"]["description"],
             "short": False},
            {"title": "First Seen",
             "value": message["detail"]["service"]["eventFirstSeen"],
             "short": True},
            {"title": "Region", "value": region, "short": True},
            {"title": "Environment", "value": environment, "short": True}
        ]
    }


def cloudwatch_notification(message, region, environment):
    states = {'OK': 'good', 'INSUFFICIENT_DATA': 'warning', 'ALARM': 'danger'}

    return {
        "color": states[message['NewStateValue']],
        "fallback": "Alarm {} triggered".format(message['AlarmName']),
        "fields": [
            {"title": "Alarm Name", "value": message['AlarmName'],
             "short": True},
            {"title": "Alarm Description", "value": message['AlarmDescription'],
             "short": False},
            {"title": "Alarm reason", "value": message['NewStateReason'],
             "short": False},
            {"title": "Old State", "value": message['OldStateValue'],
             "short": True},
            {"title": "Current State", "value": message['NewStateValue'],
             "short": True},
            {
                "title": "Link to Alarm",
                "value": "https://console.aws.amazon.com/cloudwatch/home?region=" + region + "#alarm:alarmFilter=ANY;name=" + urllib.parse.quote_plus(
                    message['AlarmName']),
                "short": False
            },
            {"title": "Environment", "value": environment, "short": True},
        ]
    }


def codepipeline_approval_notification(message, region):
    return {
        "fallback": "CodePipeline {0}-{1} Approval Requested: {2}".format(
            message["approval"]["pipelineName"], region,
            message["consoleLink"]),
        "fields": [
            {"title": "Project", "value": message["approval"]["pipelineName"],
             "short": True},
            {"title": "Action Name", "value": message["approval"]["actionName"],
             "short": True},
            {"title": "Stage Name", "value": message["approval"]["stageName"],
             "short": True},
            {"title": "Region", "value": region, "short": True}
        ],
        "actions": [
            {
                "type": "button",
                "text": "Approve",
                "style": "danger",
                "url": message["approval"]["approvalReviewLink"]
            },
            {
                "type": "button",
                "text": "Pipeline",
                "url": message["consoleLink"]
            }
        ]
    }


def default_notification(message):
    return {
        "fallback": "A new message",
        "fields": [
            {"title": "Message", "value": json.dumps(message), "short": False}]
    }


# Send a message to a slack channel
def notify_slack(message, region):
    slack_url = os.environ['SLACK_WEBHOOK_URL']
    if not slack_url.startswith("http"):
        slack_url = decrypt(slack_url)

    slack_channel = os.environ['SLACK_CHANNEL']
    slack_username = os.environ['SLACK_USERNAME']
    slack_emoji = os.environ['SLACK_EMOJI']
    environment = os.environ['ENVIRONMENT']

    payload = {
        "channel": slack_channel,
        "username": slack_username,
        "icon_emoji": slack_emoji,
        "attachments": []
    }
    if "AlarmName" in message:
        notification = cloudwatch_notification(message, region, environment)
        payload['text'] = "AWS CloudWatch notification - " + message[
            "AlarmName"]
        payload['attachments'].append(notification)
    elif "approval" in message:
        notification = codepipeline_approval_notification(message, region)
        payload['text'] = "AWS CodePipeline Approval - " + message["approval"][
            "pipelineName"]
        payload['attachments'].append(notification)
    elif "source" in message and message["source"] == "aws.ec2":
        notification = ec2_notification(message, region, environment)
        payload['text'] = "EC2 Instance Terminated: " + message["detail"][
            "instance-id"]
        payload['attachments'].append(notification)
    elif message['source'] == "aws.guardduty":
        notification = guardduty_notification(message, region, environment)
        payload['text'] = "AWS GuardDuty notification - " + message["detail"][
            "type"]
        payload['attachments'].append(notification)
    else:
        payload['text'] = "AWS notification"
        payload['attachments'].append(default_notification(message))

    data = urllib.parse.urlencode({"payload": json.dumps(payload)}).encode(
        "utf-8")
    req = urllib.request.Request(slack_url)
    urllib.request.urlopen(req, data)


def lambda_handler(event, context):
    message = json.loads(event['Records'][0]['Sns']['Message'])
    region = event['Records'][0]['Sns']['TopicArn'].split(":")[3]
    notify_slack(message, region)

    return message

# notify_slack({"AlarmName":"Example","AlarmDescription":"Example alarm description.","AWSAccountId":"000000000000","NewStateValue":"ALARM","NewStateReason":"Threshold Crossed","StateChangeTime":"2017-01-12T16:30:42.236+0000","Region":"EU - Ireland","OldStateValue":"OK"}, "eu-west-1")
