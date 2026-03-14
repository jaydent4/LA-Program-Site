# need to install pip install requests, airtable, python-dotenv
from pyairtable import Api
from pyairtable.formulas import AND, GTE, Field, match, FIND, NOT
import os
from dotenv import load_dotenv
import json

load_dotenv()
API_KEY = os.environ.get('API_KEY')
BASE_ID = os.environ.get('BASE_ID')

if not API_KEY:
    raise ValueError(f'ERROR: Missing API_KEY')

if not BASE_ID:
    raise ValueError(f'ERROR: Missing BASE_ID')

def get_course_names(table):
    record_to_course = {}
    records = table.all(fields=['Course on AirTable'])
    for record in records:
        record_to_course[record['id']] = record['fields']['Course on AirTable']
    return record_to_course

def lambda_handler(event, context):
    api = Api(API_KEY)
    roster_table = api.table(BASE_ID, 'LA Roster')
    course_table = api.table(BASE_ID, 'List of Courses')
    record_to_course = get_course_names(course_table)
    is_active = 'AND(NOT(FIND("Withdrew", {Position})), {Course} != "", {Position} != "", {Email} != "", {Name} != "")'
    records = roster_table.all(
        fields=['Name', 'Email', 'Course', 'Position'],
        formula=is_active
    )
    response = []
    for record in records:
        reformat_record = {
            'Name': record['fields']['Name'],
            'Email': record['fields']['Email'][0],
            'Course': [record_to_course[course_id] for course_id in record['fields']['Course']]
        }
        response.append(reformat_record)
    
    print(f"OBTAINED {len(response)} records")
    print(response)
        
lambda_handler(None, None)