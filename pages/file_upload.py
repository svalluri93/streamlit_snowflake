import numpy as np
import altair as alt
import pandas as pd
import streamlit as st

st.title('first app')
st.subheader('section 1')
uploaded_file = st.file_uploader('pick file')

if uploaded_file is not None:
    
    total_size = uploaded_file.size
    
    # Use the st.progress function to display a progress bar
    progress_bar = st.progress(0)
    
    # Read the file and update the progress bar with each iteration
    bytes_read = 0
    with st.spinner('Uploading file...'):
        while bytes_read < total_size:
            # Read the file in chunks
            chunk = uploaded_file.read(1024)
            bytes_read += len(chunk)
            
            # Update the progress bar with the percentage of the file uploaded
            progress = bytes_read / total_size
            progress_bar.progress(progress)
    
    # Display a message when the upload is complete
    st.success('Upload complete!')

   # Can be used wherever a "file-like" object is accepted:
    #dataframe = pd.read_csv(uploaded_file)
    #st.write(dataframe)




video_file = open('C:\\Users\suryavalluri\Downloads\Snowflake_training_part_3-20221221_090615-Meeting_Recording.mp4', 'rb')
video_bytes = video_file.read()
st.video(video_bytes)

