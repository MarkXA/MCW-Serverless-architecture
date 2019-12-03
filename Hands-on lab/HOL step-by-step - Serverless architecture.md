![Microsoft Cloud Workshops](https://github.com/Microsoft/MCW-Template-Cloud-Workshop/raw/master/Media/ms-cloud-workshop.png 'Microsoft Cloud Workshops')

<div class="MCWHeader1">
Serverless architecture
</div>

<div class="MCWHeader2">
Hands-on lab step-by-step
</div>

<div class="MCWHeader3">
November 2019
</div>

Information in this document, including URL and other Internet Web site references, is subject to change without notice. Unless otherwise noted, the example companies, organizations, products, domain names, e-mail addresses, logos, people, places, and events depicted herein are fictitious, and no association with any real company, organization, product, domain name, e-mail address, logo, person, place or event is intended or should be inferred. Complying with all applicable copyright laws is the responsibility of the user. Without limiting the rights under copyright, no part of this document may be reproduced, stored in or introduced into a retrieval system, or transmitted in any form or by any means (electronic, mechanical, photocopying, recording, or otherwise), or for any purpose, without the express written permission of Microsoft Corporation.

Microsoft may have patents, patent applications, trademarks, copyrights, or other intellectual property rights covering subject matter in this document. Except as expressly provided in any written license agreement from Microsoft, the furnishing of this document does not give you any license to these patents, trademarks, copyrights, or other intellectual property.

The names of manufacturers, products, or URLs are provided for informational purposes only and Microsoft makes no representations and warranties, either expressed, implied, or statutory, regarding these manufacturers or the use of the products with any Microsoft technologies. The inclusion of a manufacturer or product does not imply endorsement of Microsoft of the manufacturer or product. Links may be provided to third party sites. Such sites are not under the control of Microsoft and Microsoft is not responsible for the contents of any linked site or any link contained in a linked site, or any changes or updates to such sites. Microsoft is not responsible for webcasting or any other form of transmission received from any linked site. Microsoft is providing these links to you only as a convenience, and the inclusion of any link does not imply endorsement of Microsoft of the site or the products contained therein.

© 2019 Microsoft Corporation. All rights reserved.

Microsoft and the trademarks listed at <https://www.microsoft.com/legal/intellectualproperty/Trademarks/Usage/General.aspx> are trademarks of the Microsoft group of companies. All other trademarks are property of their respective owners.

**Contents**

<!-- TOC -->

- [Abstract and learning objectives](#abstract-and-learning-objectives)
- [Overview](#overview)
- [Solution architecture](#solution-architecture)
- [Requirements](#requirements)
- [Exercise 1: Azure data, storage, and serverless environment setup](#exercise-1-azure-data-storage-and-serverless-environment-setup)
- [Exercise 2: Develop and publish the photo processing and data export functions](#exercise-2-develop-and-publish-the-photo-processing-and-data-export-functions)
- [Exercise 3: Create functions in the portal](#exercise-3-create-functions-in-the-portal)
- [Exercise 4: Monitor your functions with Application Insights](#exercise-4-monitor-your-functions-with-application-insights)
- [Exercise 5: Explore your data in Azure Cosmos DB](#exercise-5-explore-your-data-in-azure-cosmos-db)
- [Exercise 6: Create the data export workflow](#exercise-6-create-the-data-export-workflow) - [Exercise 7: Configure continuous deployment for your Function App](#exercise-7-configure-continuous-deployment-for-your-function-app)
- [Exercise 8: Rerun the workflow and verify data export](#exercise-8-rerun-the-workflow-and-verify-data-export)
- [After the hands-on lab](#after-the-hands-on-lab)

<!-- /TOC -->

# Serverless architecture hands-on lab step-by-step

## Abstract and learning objectives

In this hand-on lab, you will be challenged to implement an end-to-end scenario using a supplied sample that is based on Microsoft Azure Functions, Azure Cosmos DB, Event Grid, and related services. The scenario will include implementing compute, storage, workflows, and monitoring, using various components of Microsoft Azure. The hands-on lab can be implemented on your own, but it is highly recommended to pair up with other members at the lab to model a real-world experience and to allow each member to share their expertise for the overall solution.

At the end of the hands-on-lab, you will have confidence in designing, developing, and monitoring a serverless solution that is resilient, scalable, and cost-effective.

## Overview

Contoso Ltd. is rapidly expanding their toll booth management business to operate in a much larger area. As this is not their primary business, which is online payment services, they are struggling with scaling up to meet the upcoming demand to extract license plate information from a large number of new tollbooths, using photos of vehicles uploaded to cloud storage. Currently, they have a manual process where they send batches of photos to a 3rd-party who manually transcodes the license plates to CSV files that they send back to Contoso to upload to their online processing system. They want to automate this process in a way that is cost effective and scalable. They believe serverless is the best route for them, but do not have the expertise to build the solution.

## Solution architecture

Below is a diagram of the solution architecture you will build in this lab. Please study this carefully, so you understand the whole of the solution as you are working on the various components.

![The Solution diagram is described in the text following this diagram.](../Whiteboard%20design%20session/media/preferred-solution.png 'Solution diagram')

The solution begins with vehicle photos being uploaded to an Azure Storage blobs container, as they are captured. An Event Grid subscription is created against the Blob storage create event, calling the photo processing **Azure Function** endpoint (on the side of the diagram), which in turn sends the photo to the **Cognitive Services Computer Vision API OCR** service to extract the license plate data. If processing was successful and the license plate number was returned, the function submits a new Event Grid event, along with the data, to an Event Grid topic with an event type called "savePlateData". However, if the processing was unsuccessful, the function submits an Event Grid event to the topic with an event type called "queuePlateForManualCheckup". Two separate functions are configured to trigger when new events are added to the Event Grid topic, each filtering on a specific event type, both saving the relevant data to the appropriate **Azure Cosmos DB** collection for the outcome, using the Cosmos DB output binding. A **Logic App** that runs on a 15-minute interval executes an Azure Function via its HTTP trigger, which is responsible for obtaining new license plate data from Cosmos DB and exporting it to a new CSV file saved to Blob storage. If no new license plate records are found to export, the Logic App sends an email notification to the Customer Service department via their Office 365 subscription. **Application Insights** is used to monitor all of the Azure Functions in real-time as data is being processed through the serverless architecture. This real-time monitoring allows you to observe dynamic scaling first-hand and configure alerts when certain events take place. **Azure Key Vault** is used to securely store secrets, such as connection strings and access keys. Key Vault is accessed by the Function Apps through an access policy within Key Vault, assigned to each Function App's system-assigned managed identity.

## Requirements

- Microsoft Azure subscription (non-Microsoft subscription)
- Local machine or a virtual machine configured with (**complete the day before the lab!**):
  - Visual Studio Community 2019 or greater
    - <https://www.visualstudio.com/vs/>
  - Azure development workload for Visual Studio
    - <https://docs.microsoft.com/azure/azure-functions/functions-develop-vs#prerequisites>
  - .NET Framework 4.7 runtime (or higher) and .NET Core 2.1 (or higher)
    - <https://www.microsoft.com/net/download/windows>
- An email account.

## Exercise 1: Azure data, storage, and serverless environment setup

**Duration**: 10 minutes

You must provision a few resources in Azure before you start developing the solution. To save time, I've scripted the deployment for you.

### Task 1: Provision the resources

1. **IF** you have the current release of Azure PowerShell:
    - Open PowerShell on your PC.

2. **OTHERWISE**
    - Using a new tab or instance of your browser, navigate to the Azure portal, <https://portal.azure.com>.
    - Open Cloud Shell using the leftmost icon in the top bar.
    - If a Bash shell opens, switch to PowerShell.

3. Clone the Git repository to your cloud drive: `git clone https://github.com/MarkXA/serverless-workshop.git`

4. Change into the `Hands-on lab\starter` folder.

5. Run the `.\deploy.ps1` script.

6. Supply the name of a resource group to create (e.g. serverless-workshop) and a unique suffix (e.g. your initals and some random digits).

7. Wait for the script to complete. If there were errors, repeat the deployment (it will be quicker the second time!).

8. Navigate to the newly created resource group (easiest way is to type the name in the portal search box).

9. Check that the following resources have been created:

    - Two Azure Functions function apps with matching app service plans and storage accounts (one .NET and one Node)
    - An Event Grid topic
    - A Cosmos DB account (browse to see database and containers)
    - A Cognitive Services Computer Vision account
    - A storage account for holding image blobs
    - An Application Insights instance
    - A Key Vault

## Exercise 2: Develop and publish the photo processing and data export functions

**Duration**: 30 minutes

Use Visual Studio and its integrated Azure Functions tooling to develop and debug the functions locally, and then publish them to Azure. The starter project solution, TollBooths, contains most of the code needed. You will add in the missing code before deploying to Azure.

### Help references

|                                       |                                                                        |
| ------------------------------------- | :--------------------------------------------------------------------: |
| **Description**                       |                               **Links**                                |
| Code and test Azure Functions locally | <https://docs.microsoft.com/azure/azure-functions/functions-run-local> |

### Task 1: Check application settings

In this task, you will check the application settings using the Microsoft Azure Portal.

1. In the portal, navigate to your resource group, then select the .NET Azure Function App.

    ![In the ServerlessArchtecture resource group, TollBoothFunctionApp is selected.](media/image33.png 'ServerlessArchtecture resource group')

2. Select **Configuration** on the Overview pane.

    ![In the TollBoothFunctionApp blade, under Configured features, Application settings is selected.](media/image34.png 'TollBoothFunctionApp blade')

3. Examine the application settings that the app will use to access resources. Note that the sensitive settings are stored as references to Key Vault.

### Task 2: View the system-assigned managed identity for your function app

1. In the Function App, navigate to **Platform features**.

2. Select **Identity**.

3. Check that **Status** is set to **On**. This means that the Function App has an identity in Azure Active Directory.

### Task 3: Check the function app's Key Vault access policy

Check there is an access policy that enables the "Get" secret permission for the function app:

1. Open your Key Vault service.

2. Select **Access policies**.

3. The Function App's managed identity should have an access policy that allows it to get secrets.

    ![Key Vault access policies.](media/key-vault-access-policies.png "Access policies")

### Task 4: Finish the ProcessImage function

There are a few components within the starter project that must be completed, marked as TODO in the code. The first set of TODO items we will address are in the ProcessImage function, the FindLicensePlateText class that calls the Computer Vision API, and finally the SendToEventGrid.cs class, which is responsible for sending processing results to the Event Grid topic you created earlier.

> **Note:** Do **NOT** update the version of any NuGet package. This solution is built to function with the NuGet package versions currently defined within. Updating these packages to newer versions could cause unexpected results.

1. Navigate to the **TollBooth** project (`Hands-on lab\starter\TollBooth\TollBooth.sln`) using the Solution Explorer of Visual Studio.

2. From the Visual Studio **View** menu, select **Task List**.

    ![The Visual Studio Menu displays, with View and Task List selected.](media/vs-task-list-link.png 'Visual Studio Menu')

3. There you will see a list of TODO tasks, where each task represents one line of code that needs to be completed.

    ![A list of TODO tasks, including their description, project, file, and line number display.](media/vs-task-list.png 'TODO tasks')

4. Open **ProcessImage.cs**. Notice that the Run method is decorated with the FunctionName attribute, which sets the name of the Azure Function to "ProcessImage". This is triggered by HTTP requests sent to it from the Event Grid service. You tell Event Grid that you want to get these notifications at your function's URL by creating an event subscription, which you will do in a later task, in which you subscribe to blob-created events. The function's trigger watches for new blobs being added to the images container of the storage account that was created in Exercise 1. The data passed to the function from the Event Grid notification includes the URL of the blob. That URL is in turn passed to the input binding to obtain the uploaded image from Blob storage.

5. The following code represents the completed task in ProcessImage.cs:

    ```csharp
    // **TODO 1: Set the licensePlateText value by awaiting a new FindLicensePlateText.GetLicensePlate method.**

    licensePlateText = await new FindLicensePlateText(log, _client).GetLicensePlate(licensePlateImage);
    ```

6. Open **FindLicensePlateText.cs**. This class is responsible for contacting the Computer Vision API to find and extract the license plate text from the photo, using OCR. Notice that this class also shows how you can implement a resilience pattern using [Polly](https://github.com/App-vNext/Polly), an open source .NET library that helps you handle transient errors. This is useful for ensuring that you do not overload downstream services, in this case, the Computer Vision API. This will be demonstrated later on when visualizing the Function's scalability.

7. The following code represents the completed task in FindLicensePlateText.cs:

    ```csharp
    // TODO 2: Populate the below two variables with the correct AppSettings properties.
    var uriBase = Environment.GetEnvironmentVariable("computerVisionApiUrl");
    var apiKey = Environment.GetEnvironmentVariable("computerVisionApiKey");
    ```

8. Open **SendToEventGrid.cs**. This class is responsible for sending an Event to the Event Grid topic, including the event type and license plate data. Event listeners will use the event type to filter and act on the events they need to process. Make note of the event types defined here (the first parameter passed into the Send method), as they will be used later on when creating new functions in the second Function App you provisioned earlier.

9. The following code represents the completed tasks in `SendToEventGrid.cs`:

    ```csharp
    // TODO 3: Modify send method to include the proper eventType name value for saving plate data.
    await Send("savePlateData", "TollBooth/CustomerService", data);

    // TODO 4: Modify send method to include the proper eventType name value for queuing plate for manual review.
    await Send("queuePlateForManualCheckup", "TollBooth/CustomerService", data);
    ```

    > **Note**: TODOs 5, 6, and 7 will be completed in later steps of the guide.

### Task 5: Publish the Function App from Visual Studio

In this task, you will publish the Function App from the starter project in Visual Studio to the existing Function App you provisioned in Azure.

1. Navigate to the **TollBooth** project using the Solution Explorer of Visual Studio.

2. Right-click the **TollBooth** project and select **Publish** from the context menu.

    ![In Solution Explorer, TollBooth is selected, and in its right-click menu, Publish is selected.](media/image39.png 'Solution Explorer ')

3. In the Pick a Publish Target window that appears, make sure **Azure Functions Consumption Plan** is selected, choose the **Select Existing** radio button, check the **Run from package file** checkbox, then select **Publish**.

    ![In the Publish window, the Azure Function App tile is selected. Under this, both the Select Existing radio button and the Publish button are selected.](media/vs-publish-function.png 'Publish window')

    > **Note**: If you do not see the ability to publish to an Azure Function, you may need to update your Visual Studio instance.

4. In the App Service form, select your **Subscription**, select **Resource Group** under **View**, then expand your resource group and select the Function App whose name contains **-net-**.

5. Whatever you named the Function App when you provisioned it is fine. Just make sure it is the same one to which you applied the Application Settings in Task 1 of this exercise.

    ![In the App Service form, Resource Group displays in the View field, and in the tree-view below, the ServerlessArchitecture folder is expanded, and TollBoothFunctionApp is selected.](media/image41.png 'App Service form')

6. After you select the Function App, select **OK**.

    > **Note**: If prompted to update the functions version on Azure, select **Yes**.

7. Select **Publish** to start the process. Watch the Output window in Visual Studio as the Function App publishes. When it is finished, you should see a message that says, `========== Publish: 1 succeeded, 0 failed, 0 skipped ==========`.

8. Using a new tab or instance of your browser navigate to the Azure portal, <http://portal.azure.com>.

9. Open the resource group, then select the Azure Function App to which you just published.

10. Expand the functions underneath your Function App in the menu. You should see both functions you just published from the Visual Studio solution listed.

    ![In the TollBoothFunctionApp blade, in the pane, both TollBoothFunctionApp, and Functions (Read Only) are expanded. Below Functions, two functions (ExportLicensePlates and ProcessImage) are called out.](media/image42.png 'TollBoothFunctionApp blade')

11. Now we need to add an Event Grid subscription to the ProcessImage function, so the function is triggered when new images are added to blob storage. Select the **ProcessImage** function, then select **Add Event Grid subscription**.

    ![The ProcessImage function and the Add Event Grid subscription items are highlighted.](media/processimage-add-eg-sub.png 'ProcessImage function')

12. On the **Create Event Subscription** blade, specify the following configuration options:

    a. **Name**: Unique value for the App name similar to **processimagesub** (ensure the green check mark appears).

    b. **Event Schema**: Select Event Grid Schema.

    c. For **Topic Type**, select **Storage Accounts**.

    d. Select your **subscription** and resource group.

    e. For resource, select your recently created storage account.

    f. Select only the **Blob Created** from the event types dropdown list.

    g. Leave Web Hook as the Endpoint Type.

13. Leave the remaining fields at their default values and select **Create**.

    ![In the Create Event Subscription blade, fields are set to the previously defined settings.](media/processimage-eg-sub.png)

## Exercise 3: Create functions in the portal

**Duration**: 45 minutes

Create two new Azure Functions written in Node.js, using the Azure portal. These will be triggered by Event Grid and output to Azure Cosmos DB to save the results of license plate processing done by the ProcessImage function.

### Help references

|                                                                   |                                                                                                         |
| ----------------------------------------------------------------- | :-----------------------------------------------------------------------------------------------------: |
| **Description**                                                   |                                                **Links**                                                |
| Create your first function in the Azure portal                    |        <https://docs.microsoft.com/azure/azure-functions/functions-create-first-azure-function>         |
| Store unstructured data using Azure Functions and Azure Cosmos DB | <https://docs.microsoft.com/azure/azure-functions/functions-integrate-store-unstructured-data-cosmosdb> |

### Task 1: Create function to save license plate data to Azure Cosmos DB

In this task, you will create a new Node.js function triggered by Event Grid and that outputs successfully processed license plate data to Azure Cosmos DB.

1. Using a new tab or instance of your browser navigate to the Azure portal, <http://portal.azure.com>.

2. Open the resource group, then select the Azure Function App you created whose name contains **-node-**. If you did not use this naming convention, make sure you select the Function App that you _did not_ deploy to in the previous exercise.

3. In the blade menu, select **Functions**, the select **+ New Function**.

    ![In the TollBoothEvents2 blade, in the pane under Function Apps, TollBoothEvents2 is expanded, and Functions is selected. In the pane, the + New function button is selected.](media/function-app-events-overview.png 'TollBoothEvents2 blade')

4. Select **In-portal** within the _Choose a development environment_ step, then select **Continue**.

    ![The In-portal option and Continue button are highlighted.](media/new-function-in-portal.png "Azure Functions for JavaScript blade")

5. Select **More templates...** within the _Create a function_ step, then select **Finish and view templates**.

    ![The More templates option and Finish and view templates button are higlighted.](media/new-function-more-templates.png "Azure Functions for JavaScript blade")

6. Enter **event grid** into the template search form, then select the **Azure Event Grid trigger** template.

    ![In the Template search form, event grid is typed in the search field. Below, the Event Grid trigger function option displays.](media/new-function-event-grid-trigger-template.png "Template search form")

    a. If prompted to install the Azure Event Grid trigger extension, select **Install** and wait for the extension to install.

    ![Install azure extension form.](media/install-function-extension.png 'Template search form')

    b. Select **Continue**.

7. In the _New Function_ form, enter `SavePlateData` for the **Name**, then select **Create**.

    ![SavePlateData is entered in the Name field and the Create button is highlighted.](media/new-function-saveplatedata.png "New Function form")

8. Replace the code in the new SavePlateData function with the following:

    ```javascript
    module.exports = function(context, eventGridEvent) {
    context.log(typeof eventGridEvent);
    context.log(eventGridEvent);

    context.bindings.outputDocument = {
        fileName: eventGridEvent.data['fileName'],
        licensePlateText: eventGridEvent.data['licensePlateText'],
        timeStamp: eventGridEvent.data['timeStamp'],
        exported: false
    };

    context.done();
    };
    ```

9. Select **Save**.

### Task 2: Add an Event Grid subscription to the SavePlateData function

In this task, you will add an Event Grid subscription to the SavePlateData function. This will ensure that the events sent to the Event Grid topic containing the savePlateData event type are routed to this function.

1. With the SavePlateData function open, select **Add Event Grid subscription**.

    ![In the SavePlateData blade, the Add Event Grid subscription link is selected.](media/saveplatedata-add-eg-sub.png 'SavePlateData blade')

2. On the **Create Event Subscription** blade, specify the following configuration options:

    a. **Name**: Unique value for the App name similar to **saveplatedatasub** (ensure the green check mark appears).

    b. **Event Schema**: Select **Event Grid Schema**.

    c. For **Topic Type**, select **Event Grid Topics**.

    d. Select your **subscription** and resource group.

    e. For resource, select your recently created Event Grid.

    f. For Event Types, select **Add Event Type**.

    g. Enter `savePlateData` for the new event type value. This will ensure this function is only triggered by this Event Grid type.

    h. Leave Web Hook as the Endpoint Type.

3. Leave the remaining fields at their default values and select **Create**.

    ![In the Create Event Subscription blade, fields are set to the previously defined settings.](media/saveplatedata-eg-sub.png "Create Event Subscription")

### Task 3: Add an Azure Cosmos DB output to the SavePlateData function

In this task, you will add an Azure Cosmos DB output binding to the SavePlateData function, enabling it to save its data to the Processed collection.

1. Expand the **SavePlateData** function in the menu, then select **Integrate**.

2. Under Outputs, select **+ New Output**, select **Azure Cosmos DB** from the list of outputs, then choose **Select**.

    ![In the SavePlateData blade, in the pane under Function Apps, TollBoothEvents2, Functions, and SavePlateData are expanded, and Integrate is selected. In the pane, + New Output is selected under Outputs. In the list of outputs, the Azure Cosmos DB tile is selected.](media/image48.png 'SavePlateData blade')

3. In the Azure Cosmos DB output form, select **new** next to the Azure Cosmos DB account connection field.

    ![The New button is selected next to the Azure Cosmos DB account connection field.](media/image49.png 'New button')

    > **Note**: If you see a notice for "Extensions not installed", select **Install**.

    ![Cosmos Extension needed.](media/cosmos-extension-install.png 'New button')

4. Select your Cosmos DB account from the list that appears.

5. Specify the following configuration options in the Azure Cosmos DB output form:

    a. For database name, type **LicensePlates**.

    b. For the collection name, type **Processed**.

    ![Under Azure Cosmos DB output the following field values display: Document parameter name, outputDocument; Collection name, Processed; Database name, LicensePlates; Azure Cosmos DB account conection, tollbooths_DOCUMENTDB.](media/saveplatedata-cosmos-integration.png 'Azure Cosmos DB output section')

6. Select **Save**.

    > **Note**: you should wait for the template dependency to install if you were prompted earlier.

### Task 4: Create function to save manual verification info to Azure Cosmos DB

In this task, you will create a new function triggered by Event Grid and outputs information about photos that need to be manually verified to Azure Cosmos DB.

1. Select the **+** button to the right of **Functions** in the left-hand menu to create a new function.

    ![The Add new function button is highlighted next to Functions in the left-hand menu.](media/new-function-button.png "TollBoothEvents blade")

2. Enter **event grid** into the template search form, then select the **Azure Event Grid trigger** template.

    a. If prompted, select **Install** and wait for the extension to install.

    b. Select **Continue**.

    ![Event grid displays in the choose a template search field, and in the results, Event Grid trigger displays.](media/image44.png 'Event grid trigger')

3. In the **New Function** form, fill out the following properties:

    a. For name, type **QueuePlateForManualCheckup**.

    ![In the New Function form, JavaScript is selected from the Language drop-down menu, and QueuePlateForManualCheckup is typed in the Name field.](media/image51.png 'Event Grid trigger, New Function form')

4. Select **Create**.

5. Replace the code in the new QueuePlateForManualCheckup function with the following:

    ```javascript
    module.exports = async function(context, eventGridEvent) {
    context.log(typeof eventGridEvent);
    context.log(eventGridEvent);

    context.bindings.outputDocument = {
        fileName: eventGridEvent.data['fileName'],
        licensePlateText: '',
        timeStamp: eventGridEvent.data['timeStamp'],
        resolved: false
    };

    context.done();
    };
    ```

6. Select **Save**.

### Task 5: Add an Event Grid subscription to the QueuePlateForManualCheckup function

In this task, you will add an Event Grid subscription to the QueuePlateForManualCheckup function. This will ensure that the events sent to the Event Grid topic containing the queuePlateForManualCheckup event type are routed to this function.

1. With the QueuePlateForManualCheckup function open, select **Add Event Grid subscription**.

    ![In the QueuePlateForManualCheckup blade, the Add Event Grid subscription link is selected.](media/manualcheckup-add-eg-sub.png 'QueuePlateForManualCheckup blade')

2. On the **Create Event Subscription** blade, specify the following configuration options:

    a. **Name**: Unique value for the App name similar to **queueplateformanualcheckupsub** (ensure the green check mark appears).

    b. **Event Schema**: Select **Event Grid Schema**.

    c. For **Topic Type**, select **Event Grid Topics**.

    d. Select your **subscription** and resource group.

    e. For resource, select your recently created Event Grid.

    f. For Event Types, select **Add Event Type**.

    g. Enter `queuePlateForManualCheckup` for the new event type value. This will ensure this function is only triggered by this Event Grid type.

    h. Leave Web Hook as the Endpoint Type.

3. Leave the remaining fields at their default values and select **Create**.

    ![In the Create Event Subscription blade, fields are set to the previously defined settings.](media/manualcheckup-eg-sub.png)

### Task 6: Add an Azure Cosmos DB output to the QueuePlateForManualCheckup function

In this task, you will add an Azure Cosmos DB output binding to the QueuePlateForManualCheckup function, enabling it to save its data to the NeedsManualReview collection.

1. Expand the QueuePlateForManualCheckup function in the menu, the select **Integrate**.

2. Under Outputs, select **+ New Output** then select **Azure Cosmos DB** from the list of outputs, then choose **Select**.

    ![In the blade, in the pane under Function Apps, TollBoothEvents2\ Functions\QueuePlateForManualCheckup are expanded, and Integrate is selected. In the pane, + New Output is selected under Outputs. In the list of outputs, the Azure Cosmos DB tile is selected.](media/image54.png)

3. Specify the following configuration options in the Azure Cosmos DB output form:

    a. For database name, enter **LicensePlates**.

    b. For collection name, enter **NeedsManualReview**.

    c. Select the **Azure Cosmos DB account connection** you created earlier.

    ![In the Azure Cosmos DB output form, the following field values display: Document parameter name, outputDocument; Collection name, NeedsManualReview; Database name, LicensePlates; Azure Cosmos DB account connection, tollbooths_DOCUMENTDB.](media/manualcheckup-cosmos-integration.png 'Azure Cosmos DB output form')

4. Select **Save**.

## Exercise 4: Monitor your functions with Application Insights

**Duration**: 30 minutes

Application Insights can be integrated with Azure Function Apps to provide robust monitoring for your functions. In this exercise, you will provision a new Application Insights account and configure your Function Apps to send telemetry to it.

### Help references

|                                                               |                                                                                  |
| ------------------------------------------------------------- | :------------------------------------------------------------------------------: |
| **Description**                                               |                                    **Links**                                     |
| Monitor Azure Functions using Application Insights            |     <https://docs.microsoft.com/azure/azure-functions/functions-monitoring>      |
| Live Metrics Stream: Monitor & Diagnose with 1-second latency | <https://docs.microsoft.com/azure/application-insights/app-insights-live-stream> |

### Task 1: Use the Live Metrics Stream to monitor functions in real time

Because Application Insights is integrated into your Function Apps, you can use the Live Metrics Stream to see the functions' telemetry in real time.

1. Open the Azure Function App you created whose name contains **-net-**, or the name you specified for the Function App containing the ProcessImage function.

2. Select **Application Insights** on the Overview pane.

    > **Note**: It may take a few minutes for this link to display. Try refreshing the page after a few moments.

    ![In the TollBoothFunctionApp blade, under Configured features, the Application Insights link is selected.](media/image64.png 'TollBoothFunctionApp blade')

3. In Application Insights, select **Live Metrics Stream** underneath Investigate in the menu.

    ![In the TollBoothMonitor blade, in the pane under Investigate, Live Metrics Stream is selected. ](media/image65.png 'TollBoothMonitor blade')

4. Leave the Live Metrics Stream open and go back to the starter app solution in Visual Studio.

5. Navigate to the **UploadImages** project using the Solution Explorer of Visual Studio. Right-click on **UploadImages**, then select **Properties**.

    ![In Solution Explorer, UploadImages is expanded, and Properties is selected.](media/vs-uploadimages.png 'Solution Explorer')

6. Select **Debug** in the left-hand menu, then paste the connection string for your Blob storage account into the **Command line arguments** text field. This will ensure that the required connection string is added as an argument each time you run the application. Additionally, the combination of adding the value here and the `.gitignore` file included in the project directory will prevent the sensitive connection string from being added to your source code repository in a later step.

    ![The Debug menu item and the command line arguments text field are highlighted.](media/vs-command-line-arguments.png "Properties - Debug")

7. Save your changes.

8. Right-click the **UploadImages** project in the Solution Explorer, then select **Debug** then **Start new instance**.

    ![In Solution Explorer, UploadImages is selected. From the Debug menu, Start new instance is selected.](media/vs-debug-uploadimages.png 'Solution Explorer')

9. When the console window appears, enter **1** and press **ENTER**. This uploads a handful of car photos to the images container of your Blob storage account.

    ![A Command prompt window displays, showing images being uploaded.](media/image69.png 'Command prompt window')

10. Switch back to your browser window with the Live Metrics Stream still open within Application Insights. You should start seeing new telemetry arrive, showing the number of servers online, the incoming request rate, CPU process amount, etc. You can select some of the sample telemetry in the list to the side to view output data.

    ![The Live Metrics Stream window displays information for the two online servers. Displaying line and point graphs include incoming requests, outgoing requests, and overvall health. To the side is a list of Sample Telemetry information. ](media/image70.png 'Live Metrics Stream window')

### Task 2: Observe your functions dynamically scaling when resource-constrained

In this task, you will change the Computer Vision API to the Free tier. This will limit the number of requests to the OCR service to 10 per minute. Once changed, run the UploadImages console app to upload 1,000 images again. The resiliency policy programmed into the FindLicensePlateText.MakeOCRRequest method of the ProcessImage function will begin exponentially backing off requests to the Computer Vision API, allowing it to recover and lift the rate limit. This intentional delay will greatly increase the function's response time, thus causing the Consumption plan's dynamic scaling to kick in, allocating several more servers. You will watch all of this happen in real time using the Live Metrics Stream view.

1. Open your Computer Vision API service by opening the resource group, and then selecting the **Cognitive Services** service name.

2. Select **Pricing tier** under Resource Management in the menu. Select the **F0 Free** pricing tier, then choose **Select**.

    > **Note**: If you already have an **F0** free pricing tier instance, you will not be able to create another one.

    ![In the TollboothOCR blade, under Resource Management, Pricing tier is selected. In the Choose your pricing tier blade, the F0 Free option is selected.](media/image73.png 'TollboothOCR and Choose your pricing tier blades')

3. Switch to Visual Studio, debug the **UploadImages** project again, then enter **2** and press **ENTER**. This will upload 1,000 new photos.

    ![the Command prompt window displays image uploading information.](media/image71.png 'Command Prompt window')

4. Switch back to the Live Metrics Stream window and observe the activity as the photos are uploaded. After running for a couple of minutes, you should start to notice a few things. The Request Duration will start to increase over time. As this happens, you should notice more servers being brought online. Each time a server is brought online, you should see a message in the Sample Telemetry stating that it is "Generating 2 job function(s)", followed by a Starting Host message. You should also see messages logged by the resilience policy that the Computer Vision API server is throttling the requests. This is known by the response codes sent back from the service (429). A sample message is "Computer Vision API server is throttling our requests. Automatically delaying for 32000ms".

    > **Note**: If you do not see data flow after a short period, consider restarting the Function App.

    ![In the Live Metrics Stream window, 11 servers are now online.](media/image74.png 'Live Metrics Stream window ')

5. After this has run for some time, close the UploadImages console to stop uploading photos.

6. Navigate back to the **Computer Vision** API and set the pricing tier back to **S1 Standard**.

## Exercise 5: Explore your data in Azure Cosmos DB

**Duration**: 15 minutes

In this exercise, you will use the Azure Cosmos DB Data Explorer in the portal to view saved license plate data. It is optional and can be safely skipped or left to the end.

### Help references

|                       |                                                           |
| --------------------- | :-------------------------------------------------------: |
| **Description**       |                         **Links**                         |
| About Azure Cosmos DB | <https://docs.microsoft.com/azure/cosmos-db/introduction> |

### Task 1: Use the Azure Cosmos DB Data Explorer

1. Open your Azure Cosmos DB account by opening the resource group, and then selecting the **Azure Cosmos DB account** name.

2. Select **Data Explorer** from the menu.

    ![In the Tollbooth - Data Explorer blade, Data Explorer is selected.](media/data-explorer-link.png 'Tollbooth - Data Explorer blade')

3. Expand the **Processed** collection, then select **Items**. This will list each of the JSON documents added to the collection.

4. Select one of the documents to view its contents. The first four properties are ones that were added by your functions. The remaining properties are standard and are assigned by Cosmos DB.

    ![Under Collections, Processed is expanded, and Documents is selected. On the Documents tab, a document is selected, and to the side, the first four properties of the document (fileName, licencePlateText, timeStamp, and exported) are circled.](media/data-explorer-processed.png 'Tollbooth - Data Explorer blade')

5. Expand the **NeedsManualReview** collection, then select **Items**.

6. Select one of the documents to view its contents. Notice that the filename is provided, as well as a property named "resolved". While this is out of scope for this lab, those properties can be used together to provide a manual process for viewing the photo and entering the license plate.

    ![Under Collections, NeedsManualReview is expanded, and Documents is selected. On the Documents tab, a document is selected, and to the side, the first four properties of the document (fileName, licencePlateText, timeStamp, and resolved) are circled.](media/data-explorer-needsreview.png 'Tollbooth - Data Explorer blade')

7. Right-click on the **Processed** collection and select **New SQL Query**.

    ![Under Collections, LicencePlates is expanded, and Processed is selected. From its right-click menu, New SQL Query is selected.](media/data-explorer-new-sql-query.png 'Tollbooth - Data Explorer blade')

8. Modify the SQL query to count the number of processed documents that have not been exported:

    ```sql
    SELECT VALUE COUNT(1) FROM c WHERE c.exported = false
    ```

9. Execute the query and observe the results. In our case, we have 1,369 processed documents that need to be exported.

    ![On the Query 1 tab, under Execute Query, the previously defined SQL query displays. Under Results, the number 1369 is highlighted.](media/cosmos-query-results.png 'Query 1 tab')

## Exercise 6: Create the data export workflow

**Duration**: 30 minutes

In this exercise, you create a new Logic App for your data export workflow. This Logic App will execute periodically and call your ExportLicensePlates function, then conditionally send an email if there were no records to export.

### Help references

|                                      |                                                                                                                 |
| ------------------------------------ | :-------------------------------------------------------------------------------------------------------------: |
| **Description**                      |                                                    **Links**                                                    |
| What are Logic Apps?                 |                  <https://docs.microsoft.com/azure/logic-apps/logic-apps-what-are-logic-apps>                   |
| Call Azure Functions from logic apps | <https://docs.microsoft.com/azure/logic-apps/logic-apps-azure-functions%23call-azure-functions-from-logic-apps> |

### Task 1: Create the Logic App

1. Navigate to the Azure portal, <http://portal.azure.com>.

2. Select **+ Create a resource**, then enter **logic app** into the search box on top. Select **Logic App** from the results.

    ![In the Azure Portal, in the menu, Create a resource is selected. In the New blade, logic ap is typed in the search field, and Logic App is selected in the search results.](media/new-logic-app.png 'Azure Portal')

3. Select the **Create** button on the Logic App overview blade.

4. On the **Create Logic App** blade, specify the following configuration options:

    a. For Name, type a unique value for the App name similar to **TollBoothLogic** (ensure the green check mark appears).

    b. Specify the Resource Group.

    c. Select the same **location** as your Resource Group.

    d. Select **Off** underneath Log Analytics.

    ![In the Create logic app blade, fields are set to the previously defined settings.](media/image81.png 'Create logic app blade')

5. Select **Create**. Open the Logic App once it has been provisioned.

6. In the Logic App Designer, scroll through the page until you locate the _Start with a common trigger_ section. Select the **Recurrence** trigger.

    ![The Recurrence tile is selected in the Logic App Designer.](media/image82.png 'Logic App Designer')

7. Enter **15** into the **Interval** box, and make sure Frequency is set to **Minute**. This can be set to an hour or some other interval, depending on business requirements.

8. Select **+ New step**.

    ![Under Recurrence, the Interval field is set to 15, and the + New step button is selected.](media/image83.png 'Logic App Designer Recurrence section')

9. Enter **Functions** in the filter box, then select the **Azure Functions** connector.

    ![Under Choose an action, Functions is typed in the search box. Under Connectors, Azure Functions is selected.](media/image85.png 'Logic App Designer Choose an action section')

10. Select your Function App whose name contains **-net-**, or contains the ExportLicensePlates function.

    ![Under Azure Functions, in the search results list, Azure Functions (TollBoothFunctionApp) is selected.](media/image86.png 'Logic App Designer Azure Functions section')

11. Select the **ExportLicensePlates** function from the list.

    ![Under Azure Functions, under Actions (2), Azure Functions (ExportLicensePlates) is selected.](media/logic-app-select-export-function.png 'Logic App Designer Azure Functions section')

12. This function does not require any parameters that need to be sent when it gets called. Select **+ New step**, then search for **condition**. Select the **Condition** Control option from the Actions search result.

    ![Under ExportLicensePlates, the field is blank. Under the + New step button, Add a condition is selected.](media/logicapp-add-condition.png 'Logic App Designer ExportLicensePlates section')

13. For the **value** field, select the **Status code** parameter. Make sure the operator is set to **is equal to**, then enter **200** in the second value field.

    > **Note**: This evaluates the status code returned from the ExportLicensePlates function, which will return a 200 code when license plates are found and exported. Otherwise, it sends a 204 (NoContent) status code when no license plates were discovered that need to be exported. We will conditionally send an email if any response other than 200 is returned.

    ![The first Condition field displays Status code. The second, drop-down menu field displays is equal to, and the third field is set to 200.](media/logicapp-condition.png 'Condition fields')

14. We will ignore the If true condition because we don't want to perform an action if the license plates are successfully exported. Select **Add an action** within the **If false** condition block.

    ![Under the Conditions field is an If true (green checkmark) section, and an if false (red x) section. In the If false section, Add an action is selected.](media/logicapp-condition-false-add.png 'Logic App Designer Condition fields if true/false ')

15. Enter **Send an email** in the filter box, then select the **Send an email** action for your preferred email provider.

    ![From the Actions list, Office 365 Outlook (Send an email) is selected.](media/logicapp-send-email.png 'Office 365 Outlook Actions list')

16. Select **Sign in** and sign into your email account.

    ![In the Office 365 Outlook - Send an email prompt, the Sign in button is selected.](media/image93.png 'Office 365 Outlook Sign in prompt')

17. In the Send an email form, provide the following values:

    a. Enter your email address in the **To** box.

    b. Provide a **subject**, such as **Toll Booth license plate export failed**.

    c. Enter a message into the **body**, and select the **Status code** from the ExportLicensePlates function so that it is added to the email body.

    ![Under Send an email, fields are set to the previously defined settings. ](media/logicapp-send-email-form.png 'Logic App Designer , Send an email fields')

18. Select **Save** in the tool bar to save your Logic App.

19. Select **Run** to execute the Logic App. You should start receiving email alerts because the license plate data is not being exported. This is because we need to finish making changes to the ExportLicensePlates function so that it can extract the license plate data from Azure Cosmos DB, generate the CSV file, and upload it to Blob storage.

    ![The Run button is selected on the Logic Apps Designer blade toolbar.](media/logicapp-start.png 'Logic Apps Designer blade')

20. While in the Logic Apps Designer, you will see the run result of each step of your workflow. A green checkmark is placed next to each step that successfully executed, showing the execution time to complete. This can be used to see how each step is working, and you can select the executed step and see the raw output.

    ![In the Logic App Designer, green check marks display next to Recurrence, ExportLicensePlates, Condition, and Send an email.](media/image96.png 'Logic App Designer ')

21. The Logic App will continue to run in the background, executing every 15 minutes (or whichever interval you set) until you disable it. To disable the app, go to the **Overview** blade for the Logic App and select the **Disable** button on the taskbar.

    ![The Disable button is selected on the TollBoothLogic blade top menu.](media/image97.png 'TollBoothLogic blade')

## Exercise 7: Finish code

**Duration**: 10 minutes

Continuous deployment skipped for speed. Do use Azure DevOps in real life though :)

### Task 1: Finish your ExportLicensePlates function code

1. Navigate to the **TollBooth** project using the Solution Explorer of Visual Studio.

2. From the Visual Studio **View** menu, select **Task List**.

    ![Task List is selected from the Visual Studio View menu.](media/image37.png 'Visual Studio View menu')

3. There you will see a list of TODO tasks, where each task represents one line of code that needs to be completed.

4. Open **DatabaseMethods.cs**.

5. The following code represents the completed task in DatabaseMethods.cs:

    ```csharp
    // TODO 5: Retrieve a List of LicensePlateDataDocument objects from the collectionLink where the exported value is false.
    licensePlates = _client.CreateDocumentQuery<LicensePlateDataDocument>(collectionLink,
            new FeedOptions() { EnableCrossPartitionQuery=true,MaxItemCount = 100 })
        .Where(l => l.exported == false)
        .ToList();
    // TODO 6: Remove the line below.
    ```

6. Make sure that you deleted the following line under TODO 6: `licensePlates = new List<LicensePlateDataDocument>();`.

7. Save your changes then open **FileMethods.cs**.

8. The following code represents the completed task in DatabaseMethods.cs:

    ```csharp
    // TODO 7: Asyncronously upload the blob from the memory stream.
    await blob.UploadFromStreamAsync(stream);
    ```

9. Save your changes.

10. Right-click the **TollBooth** project in Solution Explorer, then select **Publish**.

11. Publish the updated function app.

## Exercise 8: Rerun the workflow and verify data export

**Duration**: 10 minutes

With the latest code changes in place, run your Logic App and verify that the files are successfully exported.

### Task 1: Run the Logic App

1. Open your ServerlessArchitecture resource group in the Azure portal, then select your Logic App.

2. From the **Overview** blade, select **Enable**.

    ![In the TollBoothLogic, the Enable enable button is selected.](media/image113.png 'TollBoothLogic blade')

3. Now select **Run Trigger**, then select **Recurrence** to immediately execute your workflow.

    ![In the TollBoothLogic blade, Run Trigger / Recurrence is selected.](media/image114.png 'TollBoothLogic blade')

4. Select the **Refresh** button next to the Run Trigger button to refresh your run history. Select the latest run history item. If the expression result for the condition is **true**, then that means the CSV file should've been exported to Blob storage. Be sure to disable the Logic App so it doesn't keep sending you emails every 15 minutes. Please note that it may take longer than expected to start running, in some cases.

    ![In Logic App Designer, in the Condition section, under Inputs, true is circled.](media/image115.png 'Logic App Designer ')

### Task 2: View the exported CSV file

1. Open your ServerlessArchitecture resource group in the Azure portal, then select your **Storage account** you had provisioned to store uploaded photos and exported CSV files.

2. In the Overview pane of your storage account, select **Blobs**.

    ![Under Services, Blobs is selected.](media/image116.png 'Services section')

3. Select the **export** container.

    ![Export is selected under Name.](media/image117.png 'Export option')

4. You should see at least one recently uploaded CSV file. Select the filename to view its properties.

    ![In the Export blade, under name, a .csv file is selected.](media/blob-export.png 'Export blade')

5. Select **Download** in the blob properties window.

    ![In the Blob properties blade, the Download button is selected.](media/blob-download.png 'Blob properties blade')

    The CSV file should look similar to the following:

    ![A CSV file displays with the following columns: FileName, LicensePlateText, TimeStamp, and LicensePlateFound.](media/csv.png 'CSV file')

6. The ExportLicensePlates function updates all of the records it exported by setting the exported value to true. This makes sure that only new records since the last export are included in the next one. Verify this by re-executing the script in Azure Cosmos DB that counts the number of documents in the Processed collection where exported is false. It should return 0 unless you've subsequently uploaded new photos.

## After the hands-on lab

**Duration**: 5 minutes

In this exercise, attendees will deprovision any Azure resources that were created in support of the lab.

### Task 1: Delete the resource group in which you placed your Azure resources

1. From the Portal, navigate to the blade of your **Resource Group** and select **Delete** in the command bar at the top.

2. Confirm the deletion by re-typing the **resource group name** and selecting **Delete**.
