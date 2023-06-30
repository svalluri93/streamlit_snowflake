import streamlit as st

def main():
    #st.image('./images/logo-removebg-preview.png')
    #"st.session_state object:",st.session_state

    if st.session_state.get("login_token") != True:
        st.error("You are not currently logged in.")
        st.stop()
    if st.session_state.get("login_token") == True:
        logout_button_pressed = st.button("Logout")
        if logout_button_pressed:
            st.session_state["login_token"] = False
            st.success("Logout successful")

if __name__ == "__main__":
    main()