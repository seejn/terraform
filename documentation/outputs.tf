output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.example.id
}

output "ec2_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.example.public_ip
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.example.function_name
}

output "sagemaker_notebook_url" {
  description = "URL of SageMaker notebook"
  value       = aws_sagemaker_notebook_instance.example.url
}
