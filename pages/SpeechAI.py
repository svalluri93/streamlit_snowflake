

import streamlit as st
import openai

audio = st.file_uploader("Upload an audio file", type=["mp3"])

if audio is not None:
    result = openai.Audio.transcribe("whisper-1", audio, verbose=True)
    st.write(result["text"])