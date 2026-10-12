resource "aws_ecr_repository" "app" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE" # a tag (the git SHA) always means the same image
  force_delete         = true        # lets `terraform destroy` remove the repo even with images in it (demo project)

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the 10 most recent images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}
