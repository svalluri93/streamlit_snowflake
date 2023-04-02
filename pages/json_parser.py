import streamlit as st
import json
import pandas as pd

# Define a function to parse the JSON file and return a dictionary
def parse_json(json_file):
    data = json.load(json_file)
    df = pd.json_normalize(data)
    #return df
    return data

# Create the Streamlit app
st.title('JSON Viewer')
st.write('Upload a JSON file to view its contents')

# Add a file uploader to allow users to upload a JSON file
json_file = st.file_uploader('Choose a JSON file', type='json')

# If a file is uploaded, parse it and display the contents in the app
if json_file is not None:
    data = parse_json(json_file)
    st.write('### JSON File Contents')
    st.write(data)