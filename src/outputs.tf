output "cluster_name" {
  value = aws_eks_cluster.remediation.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.remediation.endpoint
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.remediation.certificate_authority[0].data
}