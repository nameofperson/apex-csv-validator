# CSV Data Validator and Uploader (Salesforce)

## Description

This is a simple batch Apex utility that allows you to check your CSV file against your Org's schema and tell you if it'll have any issues uploading (be it through Workbench, Data Import Wizard or the class itself.)

The idea behind this is the slog that uploading a set of data to an org, where you'll run into problems multiple times because of a mismatched field, extra commas or existing unknown automations (process builders, validation rules and triggers), without a way to quickly retry the operation with an updated CSV.

**IMPORTANT NOTE**: This is a work in progress, please make sure to **always** try these operations in a sandbox first. I'm not responsible if you create a bunch of records in your Production environment.

## Quick Start

- Upload your CSV as a static resource from within Setup
- Use the Developer Console to run the batch from the Execute Anonymous dialog, providing the correct parameters for your operation

```
Database.executeBatch(new DataUploadValidator_BATCH(<StaticResourceName>, <TargetObjectName>, null, <OperationType>), 200);
```
- The results of your operation will be provided in the final log of the batch.

## Contribute

**TBD**

## License

MIT License, 
Copyright (c) 2019 Jorge Luis Pérez Pratt

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.