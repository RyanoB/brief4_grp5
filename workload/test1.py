from email import header
from requests_toolbelt import MultipartEncoder
import requests

url = "https://magentobrief4.eastus2.cloudapp.azure.com/rest/default/V1/customers"


headers = {
        'Content-Type': 'application/json'
    }

i = 1
while i < 3000:
    json_data = {
    "customer": {
        "email": "test"+str(i)+"@meetanshi.com",
        "firstname": "John"+str(i)+"",
        "lastname": "Deo",
    },
    "password": "Meet@123"
    }
    i += 1
    r = requests.post(url, headers=headers,json=json_data, verify=False)
    print(i)
    print("\n")
    print(r.content)
    print(r.headers)
    print(r.status_code)