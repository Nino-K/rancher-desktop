import { expect } from '@playwright/test';

import type { Locator, Page } from '@playwright/test';

export class ContainerInfoPage {
  readonly page:                 Page;
  readonly tab:                  Locator;
  readonly summaryTable:         Locator;
  readonly loadingSpinner:       Locator;
  readonly errorMessage:         Locator;
  readonly mountsSectionDetails: Locator;
  readonly mountsSection:        Locator;
  readonly envSectionDetails:    Locator;
  readonly envSection:           Locator;
  readonly commandSection:       Locator;
  readonly capsSection:          Locator;
  readonly portsSectionDetails:  Locator;
  readonly portsSection:         Locator;
  readonly labelsSection:        Locator;

  constructor(page: Page) {
    this.page = page;
    this.tab = page.getByTestId('tab-info');
    this.summaryTable = page.getByTestId('info-summary-table');
    this.loadingSpinner = page.getByTestId('info-loading');
    this.errorMessage = page.getByTestId('info-error');
    this.mountsSectionDetails = page.getByTestId('info-section-mounts');
    this.mountsSection = this.mountsSectionDetails.locator('summary');
    this.envSectionDetails = page.getByTestId('info-section-env');
    this.envSection = this.envSectionDetails.locator('summary');
    this.commandSection = page.getByTestId('info-section-command');
    this.capsSection = page.getByTestId('info-section-capabilities');
    this.portsSectionDetails = page.getByTestId('info-section-ports');
    this.portsSection = this.portsSectionDetails.locator('summary');
    this.labelsSection = page.getByTestId('info-section-labels');
  }

  async clickTab() {
    await this.tab.click();
  }

  async waitForData(timeout = 15_000) {
    await expect(this.loadingSpinner).toBeHidden({ timeout });
    await expect(this.summaryTable).toBeVisible({ timeout });
  }

  /**
   * Read the value cell of a summary row by its data-testid.
   * E.g. getSummaryValue('info-row-name') returns the container name.
   */
  async getSummaryValue(rowTestId: string): Promise<string> {
    const td = this.page.getByTestId(rowTestId).locator('td');

    return (await td.textContent())?.trim() ?? '';
  }
}
