import streamlit as st
import pandas as pd
import json
from io import StringIO

# Define a function to parse the JSON file and return a pandas DataFrame
def parse_json(json_file):
    
    with open(json_file) as f:
        data = json.load(f)
    json_string = json.dumps(data)

    st.write(json_string)
    df = pd.json_normalize(data)
    return df

# Create the Streamlit app
st.title('JSON to CSV Converter')
st.write('Upload a JSON file to convert it to CSV format')

# Add a file uploader to allow users to upload a JSON file
json_file = st.file_uploader('Choose a JSON file', type='json')

# If a file is uploaded, parse it and display it in CSV format
if json_file is not None:
    df = parse_json(json_file)
    st.write('### JSON File Contents')
    st.write(df)
    st.write('### CSV File Contents')
    csv_file = df.to_csv(index=False)
    st.write(csv_file, unsafe_allow_html=True)


