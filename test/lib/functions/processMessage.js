'use strict'

const Lab = require('@hapi/lab')
const lab = exports.lab = Lab.script()
const Code = require('@hapi/code')
const sinon = require('sinon')
const fs = require('fs')
const path = require('path')
const processMessage = require('../../../lib/functions/processMessage').processMessage
const service = require('../../../lib/helpers/service')
const aws = require('../../../lib/helpers/aws')
const nwsAlert = { bodyXml: fs.readFileSync(path.join(__dirname, 'data', 'nws-alert.xml'), 'utf8') }
const ORIGINAL_ENV = process.env
let clock
const tomorrow = new Date(new Date().getTime() + (24 * 60 * 60 * 1000))
const identifier = '4eb3b7350ab7aa443650fc9351f02940E'
const identifierV2 = `2.49.0.0.826.1.20251106080027.${identifier}`

const expectNwsAlert = (response, putQuery, status = 'Test', msgType = 'Alert', references = false) => {
  Code.expect(response.statusCode).to.equal(200)
  Code.expect(response.body.identifier).to.equal(identifier)
  Code.expect(response.body.fwisCode).to.equal('TESTAREA1')
  Code.expect(response.body.sent).to.equal('2025-11-06T08:00:27+00:00')
  Code.expect(response.body.expires).to.equal('2025-11-16T08:00:27+00:00')
  Code.expect(response.body.status).to.equal(status)
  Code.expect(putQuery.text).to.equal('INSERT INTO "messages" ("identifier", "msg_type", "references", "alert", "fwis_code", "expires", "sent", "created", "identifier_v2", "references_v2", "alert_v2") VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)')
  Code.expect(putQuery.values[0]).to.equal(identifier)
  Code.expect(putQuery.values[1]).to.equal(msgType)
  if (references) {
    Code.expect(putQuery.values[2]).to.equal('www.gov.uk/environment-agency,4eb3b7350ab7aa443650fc9351f2,2020-01-01T00:00:00+00:00')
  } else {
    Code.expect(putQuery.values[2]).to.be.empty()
  }
  Code.expect(putQuery.values[3]).to.not.be.empty()
  Code.expect(putQuery.values[4]).to.equal('TESTAREA1')
  Code.expect(putQuery.values[5]).to.equal('2025-11-16T08:00:27+00:00')
  Code.expect(putQuery.values[6]).to.equal('2025-11-06T08:00:27+00:00')
  Code.expect(putQuery.values[7]).to.equal('2020-01-01T00:00:00.000Z')
  Code.expect(putQuery.values[8]).to.equal(identifierV2)
  if (references) {
    Code.expect(putQuery.values[9]).to.equal('www.gov.uk/environment-agency,2.49.0.0.826.1.20251106080027.4eb3b7350ab7aa443650fc9351f02940E,2020-01-01T00:00:00+00:00')
  } else {
    Code.expect(putQuery.values[9]).to.be.empty()
  }
  Code.expect(putQuery.values[10]).to.not.be.empty()
}

lab.experiment('processMessage', () => {
  lab.beforeEach(() => {
    clock = sinon.useFakeTimers(new Date('2020-01-01T00:00:00Z').getTime())
    process.env = { ...ORIGINAL_ENV }
    // mock services
    service.putMessage = (query) => {
      return new Promise((resolve, reject) => {
        resolve()
      })
    }
    service.getLastMessage = (id) => Promise.resolve({
      rows: [{
        id: '51',
        identifier: '4eb3b7350ab7aa443650fc9351f2'
      }]
    })
  })

  lab.afterEach(() => {
    clock.restore()
    sinon.restore()
  })

  lab.test('Correct data test with no previous alert on test', async () => {
    service.getLastMessage = (id) => Promise.resolve({
      rows: []
    })

    let putQuery

    service.putMessage = (query) => Promise.resolve().then(() => {
      putQuery = query
    })

    const response = await processMessage(nwsAlert)
    expectNwsAlert(response, putQuery)
  })

  lab.test('Correct data test with no previous alert on test 2', async () => {
    service.getLastMessage = () => {
      return new Promise((resolve) => {
        resolve()
      })
    }
    let putQuery
    service.putMessage = (query) => {
      return new Promise((resolve) => {
        putQuery = query
        resolve()
      })
    }
    const response = await processMessage(nwsAlert)
    expectNwsAlert(response, putQuery)
  })

  lab.test('Correct data test with no previous alert on production', async () => {
    process.env.stage = 'prd'
    let putQuery
    service.putMessage = (query) => {
      return new Promise((resolve, reject) => {
        putQuery = query
        resolve()
      })
    }

    const response = await processMessage(nwsAlert)
    expectNwsAlert(response, putQuery, 'Actual')
  })

  lab.test('Correct data test with active alert on test', async () => {
    service.getLastMessage = (id) => Promise.resolve({
      rows: [{
        id: '51',
        identifier: '4eb3b7350ab7aa443650fc9351f2',
        expires: tomorrow,
        sent: '2020-01-01T00:00:00Z',
        identifier_v2: identifierV2
      }]
    })

    let putQuery

    service.putMessage = (query) => Promise.resolve().then(() => {
      putQuery = query
    })

    const response = await processMessage(nwsAlert)
    expectNwsAlert(response, putQuery, 'Test', 'Update', true)
  })

  lab.test('Correct alert data test with an active on production', async () => {
    process.env.stage = 'prd'

    service.getLastMessage = (id) => Promise.resolve({
      rows: [{
        id: '51',
        identifier: '4eb3b7350ab7aa443650fc9351f2',
        sent: '2020-01-01T00:00:00Z',
        expires: tomorrow,
        msgType: 'Alert',
        identifier_v2: identifierV2
      }]
    })
    let putQuery
    service.putMessage = (query) => Promise.resolve().then(() => {
      putQuery = query
    })

    const response = await processMessage(nwsAlert)
    expectNwsAlert(response, putQuery, 'Actual', 'Update', true)
  })

  // ***********************************************************
  // Sad path tests
  // ***********************************************************
  lab.test('Bad data test', async () => {
    sinon.stub(aws.email, 'publishMessage').callsFake((message) => {
      return new Promise((resolve, reject) => {
        resolve()
      })
    })
    process.env.CPX_SNS_TOPIC = 'arn:aws:sns:region:account:topic'
    await Code.expect(processMessage(1)).to.reject()
  })

  lab.test('Bad data test 2', async () => {
    await Code.expect(processMessage({ bodyXml: '$%^&*' })).to.reject()
  })

  lab.test('Database error', async () => {
    service.putMessage = (query) => Promise.reject(new Error('unit test error'))
    const err = await Code.expect(processMessage(nwsAlert)).to.reject()
    Code.expect(err.message).to.equal('unit test error')
  })

  lab.test('Database error 2', async () => {
    service.getLastMessage = (id) => Promise.reject(new Error('unit test error'))

    const err = await Code.expect(processMessage(nwsAlert)).to.reject()
    Code.expect(err.message).to.equal('unit test error')
  })
  lab.test('Invalid bodyXml format test', async () => {
    // Set bodyXml to an invalid value (e.g., null, undefined, or an object)
    const invalidBodyXml = null

    // Expect the processMessage function to reject due to validation failure
    await Code.expect(processMessage({ bodyXml: invalidBodyXml })).to.reject()
  })
  lab.test('Valid bodyXml format test', async () => {
    const validBodyXml = nwsAlert.bodyXml

    await Code.expect(processMessage({ bodyXml: validBodyXml })).to.not.reject()
  })
})
