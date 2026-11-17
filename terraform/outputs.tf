output "instance_ip" {
  description = "Public IPv4 for the dedicated PZ12 EC2 instance."
  value       = aws_instance.pz12.public_ip
}

output "instance_id" {
  description = "Verify this belongs to the new lab before deploy or destroy."
  value       = aws_instance.pz12.id
}

output "security_group_id" {
  description = "Verify and remove the temporary rules on this dedicated group only."
  value       = aws_security_group.pz12.id
}
