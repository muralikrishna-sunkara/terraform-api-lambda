# terraform-api-lambda

terraform code to deploy serverless application with lambda and api gateway
![lambda serverless](https://github.com/user-attachments/assets/a138cd36-be60-4f5f-8828-ba51577f37ee)

## Overview

This repository contains Terraform configuration and Python code to deploy a serverless application on AWS using Lambda functions and API Gateway. The infrastructure is defined using HCL (HashiCorp Configuration Language), while application logic and Lambda handlers are written in Python.

## Features

- **Serverless Deployment:** Easily deploy Lambda functions using Terraform.
- **API Gateway Integration:** Expose Lambda functions via RESTful APIs.
- **Infrastructure as Code:** All resources are managed and provisioned with Terraform.
- **Python Lambda Handlers:** Write your business logic in Python.

## Repository Structure

- **Terraform (HCL):** Used for infrastructure provisioning (59%).
- **Python:** Lambda function code (41%).

Typical directories and files:
```
├── main.tf           # Main Terraform configuration
├── variables.tf      # Terraform input variables
├── outputs.tf        # Terraform output values
├── lambda/           # Python code for Lambda functions
│   └── handler.py
└── README.md
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- Python 3.x (for Lambda development and packaging)

## Usage

1. **Clone this repository**
   ```bash
   git clone https://github.com/muralikrishna-sunkara/terraform-api-lambda.git
   cd terraform-api-lambda
   ```

2. **Review and update variables**
   Edit `variables.tf` to set your desired AWS region, function names, etc.

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Review the Execution Plan**
   ```bash
   terraform plan
   ```

5. **Apply the Terraform Configuration**
   ```bash
   terraform apply
   ```
   Confirm the action when prompted.

## Lambda Function

Place your Python Lambda handler code in the `lambda/` directory. Example handler:

```python
def handler(event, context):
    return {
        "statusCode": 200,
        "body": "Hello from Lambda!"
    }
```

## API Gateway

Terraform provisions an API Gateway REST API that routes HTTP requests to your Lambda function. You can view the endpoint URL in Terraform outputs after deployment.

## Outputs

After running `terraform apply`, the output will include:

- API Gateway endpoint URL
- Lambda function name/ARN

## Testing the API

Once deployed, you can test your API Gateway endpoint using tools like `curl` or Postman.

**Example:**

Assuming your API Gateway endpoint output is:
```
https://<api-id>.execute-api.<region>.amazonaws.com/prod/hello
```

You can test with:

```bash
curl -X GET https://<api-id>.execute-api.<region>.amazonaws.com/prod/hello
```

**Expected response:**
```json
{
  "statusCode": 200,
  "body": "Hello from Lambda!"
}
```

Replace `<api-id>` and `<region>` with the values from your Terraform outputs.

For POST requests (if your Lambda supports it):

```bash
curl -X POST https://<api-id>.execute-api.<region>.amazonaws.com/prod/hello \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}'
```

## Clean Up

To destroy all resources created by this Terraform configuration:

```bash
terraform destroy
```

## License

This project is licensed under the MIT License.

## Author

- [muralikrishna-sunkara](https://github.com/muralikrishna-sunkara)

## Contributing

Contributions and suggestions are welcome! Please open issues or pull requests.
