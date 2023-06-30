import streamlit as st

def main():
    #st.image('./images/logo-removebg-preview.png')
    #"st.session_state object:",st.session_state

    if st.session_state.get("login_token") != True or st.session_state.get("role") != 'ADMIN':
        st.error("You need to login with admin credentials to access this page.")
        st.stop()
    if st.session_state.get("login_token") == True and st.session_state.get("role") == 'ADMIN':
        st.success('Welcome Admin!')


if __name__ == "__main__":
    main()