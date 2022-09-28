from email import header
from requests_toolbelt import MultipartEncoder
import requests


authToken = "eyJraWQiOiIxIiwiYWxnIjoiSFMyNTYifQ.eyJ1aWQiOjEsInV0eXBpZCI6MiwiaWF0IjoxNjYzMjI4NTk3LCJleHAiOjE2NjMyMzIxOTd9.xLYPm8ABLYr1xRhDOnw16zOSmyayzfJMi8m30i2yn8A"
headers = {
        'Authorization': 'Bearer ' + authToken,
        'Content-Type': 'application/json'
    }

i = 105
while i < 1200:
    url = "https://magentobrief4.eastus2.cloudapp.azure.com/rest/default/V1/customers/+"+str(i)+""
    json_data = {

    }
    i += 1
    r = requests.delete(url, headers=headers,json=json_data, verify=False)
    print(i)
    print("\n")
    print(r.status_code)