###### test cloudfront tls scenario  ################
resource "aws_s3_bucket" "cloudfront-test" {
  bucket = "my-cloudfront-test-bucket"
  acl    = "private"
  # needed for other feature
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }

  # needed for other feature
  versioning {
    enabled = true
  }

    # For bucket logging feature
  logging {
    target_bucket = "logging-bucket"
    target_prefix = "log/"
  }
}

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.cloudfront-test.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/ABCDEFG1234567"
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

###### test rds/redshift/docdb tls scenario  ################
# Create Oracle Option Group with Oracle Native Encryption
resource "aws_db_option_group" "oracle-se2-12-1-native-encryption" {
    option_group_description      = "Option Group for oracle-se2-12-1 with native encryption"
    engine_name                   = "oracle-se2"
    major_engine_version          = "12.1"
    #Allow for Native Encryption
    option {
        option_name                 = "NATIVE_NETWORK_ENCRYPTION"
        option_settings {
            name                    = "SQLNET.ENCRYPTION_SERVER"
            value                   = "REQUIRED"
        }
        option_settings {
            name                    = "SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER"
            value                   = "SHA256,SHA384,SHA512,SHA1,MD5"
        }
        option_settings {
            name                    = "SQLNET.ENCRYPTION_TYPES_SERVER"
            value                   = "RC4_256,AES256,AES192,3DES168,RC4_128,AES128,3DES112,RC4_56,DES,RC4_40,DES40"
        }
        option_settings {
            name                    = "SQLNET.CRYPTO_CHECKSUM_SERVER"
            value                   = "REQUESTED"
        }
    }
}

resource "aws_db_parameter_group" "sqlserver-se-14-00" {
    family                      = "sqlserver-se-14.0"
    parameter {
        name                    = "rds.force_ssl"
        value                   = "1"
        apply_method            = "pending-reboot"
    }
    parameter {
        name                    = "rds.sqlserver_audit"
        value                   = "fedramp_hipaa"
        apply_method            = "pending-reboot"
    }
}

# Create postgres parameter group
resource "aws_db_parameter_group" "postgres9-6" {
    family                      = "postgres9.6"
    name   = "mypg96"
    parameter {
        name                    = "rds.force_ssl"
        value                   = "1"
        apply_method            = "pending-reboot"
    }
}

# Create aurora postgres cluster parameter group
resource "aws_rds_cluster_parameter_group" "aurora-cluster-postgres10" {
    family                      = "aurora-postgresql10"
    parameter {
        name                    = "rds.force_ssl"
        value                   = "1"
        apply_method            = "pending-reboot"
    }
    parameter {
        name                    = "rds.mark"
        value                   = "testing"
        apply_method            = "pending-reboot"
    }
}

resource "aws_db_parameter_group" "mysql-8-0" {
    family                      = "mysql8.0"
    parameter {
        name                    = "tls_version"
        value                   = "tlsv1,tlsv1.1,tlsv1.2"
        apply_method            = "pending-reboot"
    }
}

resource "aws_docdb_cluster_parameter_group" "example" {
  family      = "docdb3.6"

  parameter {
    name  = "tls"
    value = "enabled"
  }
}

resource "aws_redshift_parameter_group" "bar" {
  name   = "parameter-group-test-terraform"
  family = "redshift-1.0"

  parameter {
    name  = "require_ssl"
    value = "true"
  }
}
