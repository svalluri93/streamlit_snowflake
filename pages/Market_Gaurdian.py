import boto3
import botocore
from botocore.exceptions import ClientError
import json
from pytube import YouTube
import os
#from dotenv import load_dotenv
import time,random,string
import streamlit as st
import pandas as pd
import tempfile

#load_dotenv()


AWS_ACCESS_KEY_ID = st.secrets["aws_keys"]["AWS_ACCESS_KEY_ID"]
AWS_SECRET_ACCESS_KEY = st.secrets["aws_keys"]["AWS_SECRET_ACCESS_KEY"]

BUCKET_NAME = 'nseit-media-analytics' 

def transcribe_file(file_name):

    transcribe = boto3.client('transcribe', region_name='ap-south-1', aws_access_key_id=AWS_ACCESS_KEY_ID, aws_secret_access_key=AWS_SECRET_ACCESS_KEY)
    s3_client = boto3.client('s3',aws_access_key_id=AWS_ACCESS_KEY_ID,aws_secret_access_key=AWS_SECRET_ACCESS_KEY)
    job_name = "transcribe-job-" + str(''.join(random.choices(string.ascii_uppercase + string.digits, k=7)))
    print(job_name)
    media_format = file_name.split('.')[-1]
    print(media_format)
    print(file_name)
    #print('s3://' + BUCKET_NAME + '/' + file_name)
    transcribe.start_transcription_job(
        TranscriptionJobName=job_name,
        Media={
           'MediaFileUri': 's3://' + BUCKET_NAME + '/' + file_name
       },
        MediaFormat=media_format,
        LanguageCode="en-US",
        OutputBucketName=BUCKET_NAME
    )

    max_tries = 60
    while max_tries > 0:
        max_tries -= 1
        job = transcribe.get_transcription_job(TranscriptionJobName=job_name)
        job_status = job["TranscriptionJob"]["TranscriptionJobStatus"]
        if job_status in ["COMPLETED", "FAILED"]:
            print(f"Job {job_name} is {job_status}.")
            if job_status == "COMPLETED":
                #print(
                #    f"Download the transcript from\n"
                #    f"\t{job['TranscriptionJob']['Transcript']['TranscriptFileUri']}."
                #)
                transcript_uri = job['TranscriptionJob']['Transcript']['TranscriptFileUri']
                transcript_response = s3_client.get_object(Bucket=transcript_uri.split('/')[3], Key='/'.join(transcript_uri.split('/')[4:]))
                transcript_content = transcript_response['Body'].read().decode('utf-8')
                # Parse the transcript content
                transcript_data = json.loads(transcript_content)
                transcript_text = transcript_data['results']['transcripts'][0]['transcript']

                transcribe.delete_transcription_job(
                TranscriptionJobName=job_name)
            
                return transcript_text
            
        else:
            print(f"Waiting for {job_name}. Current status is {job_status}.")
        time.sleep(10)


def video_download_upload(video_link):

    s3_client = boto3.client('s3',aws_access_key_id=AWS_ACCESS_KEY_ID,aws_secret_access_key=AWS_SECRET_ACCESS_KEY)

    print("downloading video")
    video = YouTube(video_link)
    data_stream = video.streams.filter(progressive=True,file_extension = "mp4").first()
    file_name = data_stream.default_filename

    with tempfile.TemporaryDirectory() as tempdirname:

        data_stream.download(output_path=tempdirname)
        video_file_name = os.path.join(tempdirname, file_name)

        try:
            s3_client.head_object(Bucket = BUCKET_NAME,Key = file_name)

        except botocore.exceptions.ClientError as e:

            if e.response['Error']['Code'] == "404":

                    try:
                        response = s3_client.upload_file(Filename = video_file_name, Bucket = BUCKET_NAME,Key = file_name)
                        return response
                    except ClientError as e:
                        print(f"Error uploading file '{file_name}' to bucket '{BUCKET_NAME}': {e}")
                        return False

            else:
                raise (e)
        else:
            print('file already exists')

    return file_name

def bdrck_compltn(prompt):

    #bedrock = boto3.client(
    #service_name='bedrock',
    #region_name='us-east-1', 
    #aws_access_key_id=AWS_ACCESS_KEY_ID,aws_secret_access_key=AWS_SECRET_ACCESS_KEY
    #    )

    bedrock_runtime = boto3.client(
    service_name='bedrock-runtime',
    region_name='us-east-1', 
    aws_access_key_id=AWS_ACCESS_KEY_ID,aws_secret_access_key=AWS_SECRET_ACCESS_KEY
        )

    #available_models = bedrock.list_foundation_models()

    #for model in available_models['modelSummaries']:
    #  if 'anthropic' in model['modelId']:
    #    print(model)

    body = {"prompt": "Human: " + prompt + " \\nAssistant:",
        "max_tokens_to_sample": 300, 
        "temperature": 0}

    body = json.dumps(body)

    #print(body)

    response = bedrock_runtime.invoke_model(
        modelId='anthropic.claude-v2', 
        body=body
    )

    response_body = json.loads(response.get('body').read())
    return (response_body.get('completion'))

    #stream = response.get('body')
    #if stream:
    #    for event in stream:
    #        chunk = event.get('chunk')
    #        if chunk:
    #            print(json.loads(chunk.get('bytes').decode()))


if __name__ == "__main__":

    

    st.header('Market Guardian', divider='rainbow')
    video_url = st.text_input('Youtube URL','paste link here')
    if video_url == 'paste link here' or video_url == '':
        exit(0)
    else:
        st.video(video_url)

        #video_link = 'https://www.youtube.com/watch?v=ry2_cFPewVM' --1
        #https://www.youtube.com/watch?v=RWc0PUi3Bzs -- 2

        with st.spinner('downloading the video file and uploading to s3...'):
            video_file_name = video_download_upload(video_url)

        with st.spinner('Generating the transcription...'):
            transcript_text = transcribe_file(video_file_name)

        with st.expander("Video Transcription"):
            st.write(transcript_text)


        prompt_1 = f"""
                    create a summary with respect to stock recommendations in shared text.
                    only include the stock,stock_symbol, buy or sell recommendations also identify who suggested it,stop loss and target price.
                    out of values provided in the input the lower value will be the stop loss and the higher value will be target price.
                    The stop loss price MUST ALWAYS BE lower than target price so pick the values accordingly.
                    strictly generate details for a stock only once, DO NOT generate duplicates.
                    Return a single line for each stock.

                    Text - {transcript_text}"""
        

        with st.spinner('Generating video transcription summary...'):
            trans_sum_rep = bdrck_compltn(prompt_1)
        with st.expander("Video transcription summary"):
            st.write(trans_sum_rep)

        
        prompt_2 = f''' You will be acting as an agent who can fetch details from a given text input
                    Here are 7 critical rules for the interaction you must abide:
                    <rules>
                    1. For each stock being recommended You fetch details like speaker_name,stock_name,stock symbol,stock buy or sell, target price, stop loss price
                    2. Please identify Indian names as well
                    3. If any of the above detail is not present for any stock return 'NA' for that field
                    4. DO NOT put numerical at the very front of output.
                    5. You MUST return the output in csv format with all the collected details
                    6. stop loss and target price should always be numbers
                    7. If a range is mentioned for price then pick the higher value
                    8. Strictly do not use commas while representing numbers
                    9. STRICTLY DO NOT give reasoning or notes in the response
                    </rules> 
                    
                    Text - {trans_sum_rep}'''
        
        with st.spinner('Extracting details from summary...'):
            trans_csv_op = bdrck_compltn(prompt_2)
        with st.expander("Extracted details"):
            #st.write(trans_csv_op)
        
            if trans_csv_op is not None:
                result_array = trans_csv_op.split("\n")
                columns = result_array[0].split(',')
                result_rows = [r.split(',') for r in result_array[1::]]
                results_items = [
                    dict(zip(columns, item))
                    for item in result_rows
                ]
                #print(json.dumps(results_items, indent=4))
                df = pd.json_normalize(results_items)
                st.dataframe(df)
            else:
                st.write('No stocks recommended')
        