import { LightningElement, api } from "lwc";

export default class RecordCloneRelatedListItem extends LightningElement {
  @api
  title;
  @api
  okItems;
  @api
  ngItems;
  @api
  errorMessage;
  @api
  isError = false;

  shouldShow = false;

  toggle() {
    this.shouldShow = !this.shouldShow;
  }

  get hasElements() {
    return this.totalLength > 0;
  }

  get iconName() {
    return this.shouldShow
      ? "utility:contract_alt"
      : "utility:expand_alt";
  }

  get okLength() {
    return this.okItems ? this.okItems.length : 0;
  }

  get ngLength() {
    return this.ngItems ? this.ngItems.length : 0;
  }

  get totalLength() {
    return this.okLength + this.ngLength;
  }

}
