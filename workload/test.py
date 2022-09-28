from email import header
from requests_toolbelt import MultipartEncoder
import requests

url = "https://magentobrief4.eastus2.cloudapp.azure.com/rest/default/V1/integration/admin/token"
json_data = {
    "firtsname": "test5",
    "lastname": "test5",
    "email": "test5@gmail.com",

    "password": "testtest123!",

}

authToken = "5slobwv9x3tjqmf3e34viansv7hzcygq:hus0qjpmic945iyrb5upmql2bdqnkrco"
#'Authorization': 'Bearer ' + authToken,
headers = {
        'Content-Type': 'application/json'
    }

admin_data = {
    "username": "admin",
    "password": "admin123"
}
r = requests.post(url, headers=headers,json=admin_data, verify=False)

print(r.content.decode())

