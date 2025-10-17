import json
import boto3
import os
from datetime import datetime
import uuid
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['DYNAMODB_TABLE']
table = dynamodb.Table(table_name)

class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
        return super(DecimalEncoder, self).default(o)

def lambda_handler(event, context):
    """
    Main Lambda handler for REST API operations
    Supports: GET, POST, PUT, DELETE operations
    """
    http_method = event['requestContext']['http']['method']
    
    # Get path - remove stage name if present
    # rawPath format: /dev/items or /items
    raw_path = event['rawPath']
    path_parts = raw_path.strip('/').split('/')
    
    # Remove stage name (first part if it matches environment)
    if len(path_parts) > 0 and path_parts[0] in ['dev', 'staging', 'prod']:
        path_parts = path_parts[1:]
    
    path = '/' + '/'.join(path_parts) if path_parts else '/'
    
    print(f"DEBUG: Method={http_method}, RawPath={raw_path}, CleanPath={path}")

    try:
        # GET /items - List all items
        if http_method == 'GET' and path == '/items':
            return get_all_items()

        # POST /items - Create new item
        elif http_method == 'POST' and path == '/items':
            body = json.loads(event.get('body', '{}'))
            return create_item(body)

        # GET /items/{id} - Get specific item
        elif http_method == 'GET' and path.startswith('/items/'):
            item_id = path.split('/')[-1]
            return get_item(item_id)

        # PUT /items/{id} - Update item
        elif http_method == 'PUT' and path.startswith('/items/'):
            item_id = path.split('/')[-1]
            body = json.loads(event.get('body', '{}'))
            return update_item(item_id, body)

        # DELETE /items/{id} - Delete item
        elif http_method == 'DELETE' and path.startswith('/items/'):
            item_id = path.split('/')[-1]
            return delete_item(item_id)

        print(f"No matching route for {http_method} {path}")
        return error_response(404, f"Endpoint not found: {http_method} {path}")

    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return error_response(500, f"Internal server error: {str(e)}")

def get_all_items():
    """Retrieve all items from DynamoDB"""
    try:
        response = table.scan()
        items = response.get('Items', [])
        return success_response(200, {
            'items': items,
            'count': len(items)
        })
    except Exception as e:
        return error_response(500, f"Failed to retrieve items: {str(e)}")

def get_item(item_id):
    """Retrieve a specific item by ID"""
    try:
        response = table.get_item(Key={'id': item_id})
        if 'Item' not in response:
            return error_response(404, "Item not found")
        return success_response(200, response['Item'])
    except Exception as e:
        return error_response(500, f"Failed to retrieve item: {str(e)}")

def create_item(body):
    """Create a new item"""
    try:
        # Validate required fields
        if 'name' not in body or 'description' not in body:
            return error_response(400, "Missing required fields: name, description")

        item_id = str(uuid.uuid4())
        item = {
            'id': item_id,
            'name': body['name'],
            'description': body['description'],
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat()
        }

        # Add optional fields
        if 'price' in body:
            item['price'] = Decimal(str(body['price']))
        if 'quantity' in body:
            item['quantity'] = int(body['quantity'])

        table.put_item(Item=item)
        return success_response(201, item)
    except Exception as e:
        return error_response(500, f"Failed to create item: {str(e)}")

def update_item(item_id, body):
    """Update an existing item"""
    try:
        # Check if item exists
        response = table.get_item(Key={'id': item_id})
        if 'Item' not in response:
            return error_response(404, "Item not found")

        # Build update expression
        update_expression = "SET updated_at = :updated_at"
        expression_values = {':updated_at': datetime.utcnow().isoformat()}
        attr_names = {}

        # Allow updating name, description, price, quantity
        if 'name' in body:
            update_expression += ", #name = :name"
            expression_values[':name'] = body['name']
            attr_names['#name'] = 'name'

        if 'description' in body:
            update_expression += ", #desc = :desc"
            expression_values[':desc'] = body['description']
            attr_names['#desc'] = 'description'

        if 'price' in body:
            update_expression += ", price = :price"
            expression_values[':price'] = Decimal(str(body['price']))

        if 'quantity' in body:
            update_expression += ", quantity = :quantity"
            expression_values[':quantity'] = int(body['quantity'])

        # Perform update
        response = table.update_item(
            Key={'id': item_id},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_values,
            ExpressionAttributeNames=attr_names if attr_names else None,
            ReturnValues='ALL_NEW'
        )

        return success_response(200, response['Attributes'])
    except Exception as e:
        return error_response(500, f"Failed to update item: {str(e)}")

def delete_item(item_id):
    """Delete an item"""
    try:
        # Check if item exists
        response = table.get_item(Key={'id': item_id})
        if 'Item' not in response:
            return error_response(404, "Item not found")

        table.delete_item(Key={'id': item_id})
        return success_response(200, {'message': f"Item {item_id} deleted successfully"})
    except Exception as e:
        return error_response(500, f"Failed to delete item: {str(e)}")

def success_response(status_code, body):
    """Format successful response"""
    return {
        'statusCode': status_code,
        'body': json.dumps(body, cls=DecimalEncoder),
        'headers': {
            'Content-Type': 'application/json'
        }
    }

def error_response(status_code, message):
    """Format error response"""
    return {
        'statusCode': status_code,
        'body': json.dumps({'error': message}),
        'headers': {
            'Content-Type': 'application/json'
        }
    }