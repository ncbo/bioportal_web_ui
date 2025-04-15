export function openPopup(url, popupWidth = 800, popupHeight = 600) {
  // Append ?pop=true or &pop=true before any hash
  const hasQuery = url.includes('?');
  const hasHash = url.includes('#');
  const popParam = hasQuery ? '&pop=true' : '?pop=true';

  if (hasHash) {
    const hashIndex = url.indexOf('#');
    url = `${url.slice(0, hashIndex)}${popParam}${url.slice(hashIndex)}`;
  } else {
    url += popParam;
  }

  // Determine screen offset (for dual monitors)
  const dualScreenLeft = window.screenLeft ?? window.screenX ?? 0;
  const dualScreenTop = window.screenTop ?? window.screenY ?? 0;

  // Determine viewport size
  const screenWidth = window.innerWidth || document.documentElement.clientWidth || screen.width;
  const screenHeight = window.innerHeight || document.documentElement.clientHeight || screen.height;

  // Calculate centered position
  const left = (screenWidth - popupWidth) / 2 + dualScreenLeft;
  const top = (screenHeight - popupHeight) / 2 + dualScreenTop;

  // Build features string
  const features = `popup,scrollbars=yes,width=${popupWidth},height=${popupHeight},top=${top},left=${left}`;

  // Open the popup window
  const newWindow = window.open(url, 'bp_popup_window', features);

  newWindow?.focus();
}
