const xmldom = require('@xmldom/xmldom')
const xmlFormat = require('xml-formatter')
const { Sql } = require('sql-ts')
const sql = new Sql('postgres')
const messages = sql.define({
  name: 'messages',
  columns: ['identifier', 'msg_type', 'references', 'alert', 'fwis_code', 'expires', 'sent', 'created', 'identifier_v2', 'references_v2', 'alert_v2']
})

class Message {
  constructor (xmlString) {
    this.doc = new xmldom.DOMParser().parseFromString(xmlString, 'text/xml')
  }

  get fwisCode () {
    return this.getFirstElement('geocode').getElementsByTagName('value')[0].textContent
  }

  get identifier () {
    return this.getFirstElement('identifier').textContent
  }

  set identifier (value) {
    this.getFirstElement('identifier').textContent = value
  }

  get sender () {
    return this.getFirstElement('sender').textContent
  }

  get msgType () {
    return this.getFirstElement('msgType').textContent
  }

  set msgType (value) {
    this.getFirstElement('msgType').textContent = value
  }

  get references () {
    return this.getFirstElement('references') ? this.getFirstElement('references').textContent : ''
  }

  set references (value) {
    if (value) {
      if (this.references) {
        this.getFirstElement('references').textContent = value
      } else {
        this.addElement('scope', 'references', value)
      }
      if (this.msgType === 'Alert') {
        this.msgType = 'Update'
      }
    }
  }

  get status () {
    return this.getFirstElement('status').textContent
  }

  set status (value) {
    this.getFirstElement('status').textContent = value
  }

  get expires () {
    return this.getFirstElement('expires').textContent
  }

  get sent () {
    return this.getFirstElement('sent').textContent
  }

  getFirstElement (tagName) {
    return this.doc.getElementsByTagName(tagName)[0]
  }

  addElement (parentTag, elTag, elValue) {
    const parentEl = this.doc.getElementsByTagName(parentTag)[0]
    const newEl = this.doc.createElement(elTag)
    newEl.textContent = elValue
    return parentEl.parentNode.insertBefore(newEl, parentEl.nextSibling)
  }

  toString () {
    return xmlFormat(new xmldom.XMLSerializer().serializeToString(this.doc), { indentation: '  ', collapseContent: true })
  }

  // Handles multiple message versions to create the single database record
  putQuery (messageV1, messageV2) {
    const message = {
      identifier: messageV1.identifier,
      msg_type: messageV1.msgType,
      references: messageV1.references,
      alert: messageV1.toString(),
      fwis_code: messageV1.fwisCode,
      expires: messageV1.expires,
      sent: messageV1.sent,
      created: new Date().toISOString(),
      identifier_v2: messageV2.identifier,
      references_v2: messageV2.references,
      alert_v2: messageV2.toString()
    }
    return messages.insert(message).toQuery()
  }
}

module.exports = Message
