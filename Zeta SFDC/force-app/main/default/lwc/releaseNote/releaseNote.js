import { LightningElement, track, wire } from "lwc";
import getSectionsWithBlocksByType from "@salesforce/apex/SectionBlockController.getSectionsWithBlocksByType";
import { CurrentPageReference } from "lightning/navigation";

export default class ReleaseNote extends LightningElement {
  @track sectionsWithBlocks = [];
  @track error;

  sectionType = "Left_Top";
  pageType = "Home";

  @wire(getSectionsWithBlocksByType, {
    sectionType: "$sectionType",
    pageType: "$pageType"
  })
  wiredSections({ error, data }) {
    if (data) {
      console.log("Wired Data:", data);
      this.sectionsWithBlocks = data;
    } else if (error) {
      this.error = error.body.message;
      console.error("Error fetching section and blocks:", error);
    }
  }
}