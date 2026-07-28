# **GitHub Flow**
Step-by-step guide for cloning and pushing a new feature.



---



## **Initial Setup (Do Once)**  
Before writing code, a team member must download the repository to their local computer.

1. Open the GitHub repository page in your browser.
2. Click the green Code button and copy the URL (HTTPS or SSH).
3. Open your terminal or command prompt and run:

```
git clone https://github.com/KUBO-Capstone/kubo-mobile-app.git
```  
  

---




## **Step 1: Creating a Feature Branch**  
**Rule**: Never write code or push directly to main or master. Always create a branch for your feature.

1. Ensure you are on the main branch

> git checkout main

2. Pull the absolute latest changes from GitHub so you aren't working on old code:

> git pull origin main

3. Create and switch to a new branch (use a descriptive, hyphenated name):

> git checkout -b feature/add-login-button



## **Step 2: Saving Your Changes (Commit)**
As you write or modify code, you must save your progress locally.

1. Check which files you changed to ensure everything looks correct:

> git status

2. Stage (add) the files you want to save:

> git add .

(Tip: Replace the dot . with a specific file path if you don't want to add everything at once).

3. Save the changes with a short, descriptive message in the present tense:

> git commit -m "Add Google login button to landing page"



## **Step 3: Pushing to GitHubNow**
Send your local branch up to the GitHub cloud.

1. Push your branch using the "set upstream" command (only needed the first time you push this specific branch):

> git push -u origin feature/add-login-button



## **Step 4: The Pull Request (Review)**
Once the code is pushed, it is time for the rest of the team to review it.

1. Go to your repository page on GitHub.com.
2. You will see a yellow banner saying your branch was recently pushed. Click **Compare & pull request.**
3. Write a summary of what you built.
4. Assign team members as **Reviewers** on the right sidebar.
5. Click **Create pull request**.
6. Once a teammate reviews and approves your code, click the green **Merge pull request** button on GitHub to merge it into main.


---


##  **Summary Checklist for Daily Work**
Once the initial clone is done, the daily loop for a developer looks like this:

1. **git checkout main** + **git pull origin main** (Start fresh)
2. **git checkout -b my-new-feature** (Branch out)
3. Write code...
4. **git add .** + **git commit -m "message"** (Save work)
5. **git push -u origin my-new-feature** (Upload code)
6. Open a **Pull Request** on GitHub.
