resource "aws_sns_topic" "alerts" {
  count = var.alert_email == "" ? 0 : 1
  name  = "${var.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.name}-unhealthy-targets"
  alarm_description   = "At least one task is failing its load balancer health check"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  treat_missing_data  = "notBreaching"
  alarm_actions       = aws_sns_topic.alerts[*].arn

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
}
